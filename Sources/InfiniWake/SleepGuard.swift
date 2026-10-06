import Foundation
import IOKit.pwr_mgt

/// Держит Mac бодрствующим: IOPMAssertion + опциональный pmset-helper (закрытая крышка).
final class SleepGuard {
    enum Mode: String {
        case off
        case assertionOnly
        case pmset
    }

    private var assertionID: IOPMAssertionID = 0
    private var hasAssertion = false
    private(set) var activeMode: Mode = .off
    private(set) var lastError: String?

    /// Пути к helper: системный (после install-helper.sh), затем рядом с бинарником.
    private var helperCandidates: [String] {
        var paths: [String] = [
            "/Library/PrivilegedHelperTools/infiniwake-pmset",
            "/usr/local/libexec/infiniwake-pmset"
        ]
        let execDir = (Bundle.main.executablePath as NSString?)?.deletingLastPathComponent
        if let execDir {
            paths.append(execDir + "/infiniwake-pmset")
        }
        if let resourceHelper = Bundle.main.path(forResource: "infiniwake-pmset", ofType: nil) {
            paths.append(resourceHelper)
        }
        paths.append(NSHomeDirectory() + "/Library/Application Support/InfiniWake/infiniwake-pmset")
        return paths
    }

    private var resolvedHelper: String? {
        helperCandidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    var hasPrivilegedHelper: Bool {
        resolvedHelper != nil
    }

    @discardableResult
    func enable() -> Bool {
        lastError = nil

        if let helper = resolvedHelper {
            if runHelper(helper, argument: "on") {
                activeMode = .pmset
                // Дополнительная assertion на случай, если helper недоступен позже
                _ = createAssertion()
                return true
            }
            lastError = "Не удалось вызвать infiniwake-pmset on"
        }

        if createAssertion() {
            activeMode = .assertionOnly
            return true
        }

        activeMode = .off
        return false
    }

    @discardableResult
    func disable() -> Bool {
        lastError = nil
        releaseAssertion()

        if let helper = resolvedHelper {
            if runHelper(helper, argument: "off") {
                activeMode = .off
                return true
            }
            // Даже если helper упал — assertion уже снята
            lastError = "Не удалось вызвать infiniwake-pmset off"
            activeMode = .off
            return false
        }

        activeMode = .off
        return true
    }

    func sleepDisplayIfNeeded() {
        guard let helper = resolvedHelper else { return }
        _ = runHelper(helper, argument: "display-sleep")
    }

    private func createAssertion() -> Bool {
        if hasAssertion {
            return true
        }
        let name = "InfiniWake keep-awake" as CFString
        let status = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            name,
            &assertionID
        )
        hasAssertion = (status == kIOReturnSuccess)
        if !hasAssertion {
            lastError = "IOPMAssertionCreate failed: \(status)"
        }
        return hasAssertion
    }

    private func releaseAssertion() {
        guard hasAssertion else { return }
        IOPMAssertionRelease(assertionID)
        hasAssertion = false
        assertionID = 0
    }

    private func runHelper(_ path: String, argument: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", path, argument]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
}
