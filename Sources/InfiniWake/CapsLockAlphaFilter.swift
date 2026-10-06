import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Убирает настоящий Caps Lock из ввода, пока InfiniWake держит LED как индикатор.
/// Требует разрешение Accessibility. Не логирует нажатия.
final class CapsLockAlphaFilter {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isTapInstalled = false

    /// Фильтр активен только когда keep-awake + LED.
    private var shouldFilter = false

    var isTrusted: Bool {
        // Без prompt — иначе macOS снова покажет системный диалог
        AXIsProcessTrusted()
    }

    var isTapReady: Bool {
        isTapInstalled
    }

    /// Открыть настройки Privacy → Accessibility (без повторного системного prompt).
    func openAccessibilitySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
        ]
        for raw in urls {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    /// Один раз запросить системный диалог (не вызывать на каждый toggle).
    @discardableResult
    func promptSystemTrustDialogOnce() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Включить/выключить фильтрацию (после установки tap).
    func setFilteringEnabled(_ enabled: Bool) {
        shouldFilter = enabled
        if enabled {
            _ = ensureTapInstalled()
        }
    }

    func stop() {
        shouldFilter = false
        tearDownTap()
    }

    @discardableResult
    func ensureTapInstalled() -> Bool {
        if isTapInstalled {
            return true
        }
        guard AXIsProcessTrusted() else {
            return false
        }

        let mask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let filter = Unmanaged<CapsLockAlphaFilter>.fromOpaque(refcon).takeUnretainedValue()
                return filter.handle(type: type, event: event)
            },
            userInfo: userInfo
        ) else {
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        isTapInstalled = true
        return true
    }

    private func tearDownTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isTapInstalled = false
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard shouldFilter else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if keyCode == Int64(kVK_CapsLock) {
            if type == .flagsChanged {
                var flags = event.flags
                flags.remove(.maskAlphaShift)
                event.flags = flags
            }
            return Unmanaged.passUnretained(event)
        }

        var flags = event.flags
        if flags.contains(.maskAlphaShift) {
            flags.remove(.maskAlphaShift)
            event.flags = flags
        }
        return Unmanaged.passUnretained(event)
    }
}
