import Foundation
import IOKit
import IOKit.hidsystem
import Darwin

/// Управление лампочкой Caps Lock через IOHIDSystem.
final class CapsLockLED {
    private let lock = NSLock()
    private var connect: io_connect_t = 0
    private let logURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/InfiniWake", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("led.log")
    }()

    deinit {
        lock.lock()
        if connect != 0 {
            IOServiceClose(connect)
            connect = 0
        }
        lock.unlock()
    }

    func isOn() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return readStateLocked() ?? false
    }

    /// Быстрый read без экземпляра — для Caps Lock-хоткея.
    static func sharedQuickRead() -> Bool {
        guard let connection = CapsLockHID.openConnection() else { return false }
        defer { IOServiceClose(connection) }
        return CapsLockHID.readState(connection: connection) ?? false
    }

    /// Быстрый set без verify — для тика / recovery после смены языка.
    @discardableResult
    func setOn(_ on: Bool, verify: Bool = false) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return setStateLocked(on, verify: verify)
    }

    /// Первичное включение: verify read-back. Не рвём соединение каждый раз.
    @discardableResult
    func forceOn() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return setStateLocked(true, verify: true)
    }

    private func setStateLocked(_ target: Bool, verify: Bool) -> Bool {
        guard ensureConnectionLocked() else {
            log("set(\(target)) no connection")
            return false
        }
        guard CapsLockHID.setState(target, connection: connect) else {
            log("set(\(target)) write failed")
            return false
        }
        guard verify else {
            return true
        }

        var consecutive = 0
        var last: Bool?
        for attempt in 0..<15 {
            last = CapsLockHID.readState(connection: connect)
            if last == target {
                consecutive += 1
                if consecutive >= 2 {
                    log("set(\(target)) confirmed after \(attempt + 1) reads")
                    return true
                }
            } else {
                consecutive = 0
                _ = CapsLockHID.setState(target, connection: connect)
            }
            if attempt + 1 < 15 {
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        log("set(\(target)) NOT confirmed last=\(String(describing: last))")
        return false
    }

    private func readStateLocked() -> Bool? {
        guard ensureConnectionLocked() else { return nil }
        if let state = CapsLockHID.readState(connection: connect) {
            return state
        }
        IOServiceClose(connect)
        connect = 0
        guard ensureConnectionLocked() else { return nil }
        return CapsLockHID.readState(connection: connect)
    }

    private func ensureConnectionLocked() -> Bool {
        if connect != 0 {
            if CapsLockHID.readState(connection: connect) != nil {
                return true
            }
            IOServiceClose(connect)
            connect = 0
        }
        connect = CapsLockHID.openConnection() ?? 0
        if connect == 0 {
            log("openConnection failed")
            return false
        }
        return true
    }

    private func log(_ line: String) {
        let text = "\(ISO8601DateFormatter().string(from: Date())) \(line)\n"
        guard let data = text.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: logURL.path),
           let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: logURL)
        }
    }
}

private enum CapsLockHID {
    static func openConnection() -> io_connect_t? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching(kIOHIDSystemClass)
        )
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var connection: io_connect_t = 0
        guard IOServiceOpen(
            service,
            mach_task_self_,
            UInt32(kIOHIDParamConnectType),
            &connection
        ) == KERN_SUCCESS else {
            return nil
        }
        return connection
    }

    static func readState(connection: io_connect_t) -> Bool? {
        var state = false
        guard IOHIDGetModifierLockState(
            connection,
            Int32(kIOHIDCapsLockState),
            &state
        ) == KERN_SUCCESS else {
            return nil
        }
        return state
    }

    static func setState(_ state: Bool, connection: io_connect_t) -> Bool {
        IOHIDSetModifierLockState(
            connection,
            Int32(kIOHIDCapsLockState),
            state
        ) == KERN_SUCCESS
    }
}
