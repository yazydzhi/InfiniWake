import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

/// Пока активен Secure Event Input (поля паролей), CGEvent-фильтр alphaShift не действует —
/// символы идут как при Caps Lock. Временно гасим lock, keep-awake логически остаётся on.
enum SecureInputStateReader {
    static func isSecureEventInputEnabled() -> Bool {
        IsSecureEventInputEnabled()
    }
}

/// Быстрый путь: смена фокуса / активного приложения.
final class SecureInputFocusMonitor {
    private let onChange: () -> Void
    private var workspaceObserver: NSObjectProtocol?
    private var observer: AXObserver?
    private var applicationElement: AXUIElement?
    private var processIdentifier: pid_t?

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    func start() {
        guard workspaceObserver == nil else {
            attachToFrontmostApplication()
            return
        }

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.attachToFrontmostApplication()
            self?.onChange()
        }
        attachToFrontmostApplication()
    }

    func stop() {
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
        workspaceObserver = nil
        detachFromApplication()
    }

    fileprivate func focusDidChange() {
        onChange()
    }

    private func attachToFrontmostApplication() {
        guard AXIsProcessTrusted(),
              let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            detachFromApplication()
            return
        }
        guard processIdentifier != pid || observer == nil else { return }

        detachFromApplication()
        var createdObserver: AXObserver?
        guard AXObserverCreate(pid, secureInputFocusObserverCallback, &createdObserver) == .success,
              let createdObserver else {
            return
        }

        let applicationElement = AXUIElementCreateApplication(pid)
        let context = Unmanaged.passUnretained(self).toOpaque()
        let focusedElementResult = AXObserverAddNotification(
            createdObserver,
            applicationElement,
            kAXFocusedUIElementChangedNotification as CFString,
            context
        )
        let focusedWindowResult = AXObserverAddNotification(
            createdObserver,
            applicationElement,
            kAXFocusedWindowChangedNotification as CFString,
            context
        )
        let observesFocus = focusedElementResult == .success
            || focusedElementResult == .notificationAlreadyRegistered
            || focusedWindowResult == .success
            || focusedWindowResult == .notificationAlreadyRegistered
        guard observesFocus else { return }

        observer = createdObserver
        self.applicationElement = applicationElement
        processIdentifier = pid
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(createdObserver),
            .commonModes
        )
    }

    private func detachFromApplication() {
        if let observer {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .commonModes
            )
            if let applicationElement {
                AXObserverRemoveNotification(
                    observer,
                    applicationElement,
                    kAXFocusedUIElementChangedNotification as CFString
                )
                AXObserverRemoveNotification(
                    observer,
                    applicationElement,
                    kAXFocusedWindowChangedNotification as CFString
                )
            }
        }
        observer = nil
        applicationElement = nil
        processIdentifier = nil
    }
}

private let secureInputFocusObserverCallback: AXObserverCallback = { _, _, _, refcon in
    guard let refcon else { return }
    Unmanaged<SecureInputFocusMonitor>.fromOpaque(refcon).takeUnretainedValue().focusDidChange()
}
