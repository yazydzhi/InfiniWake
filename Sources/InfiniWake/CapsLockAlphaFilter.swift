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
        AXIsProcessTrusted()
    }

    /// Показать системный диалог Accessibility, если ещё не выдано.
    @discardableResult
    func requestTrustIfNeeded() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Открыть настройки Privacy → Accessibility.
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
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
        // Если tap отключили (timeout) — включить обратно
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

        // Событие самой клавиши Caps Lock пропускаем — нужна смена языка.
        // С символов и прочих модификаторов снимаем alphaShift, чтобы не было CAPS.
        if keyCode == Int64(kVK_CapsLock) {
            // На flagsChanged от Caps Lock тоже убираем alphaShift из флагов,
            // чтобы система не считала «режим заглавных» активным для следующего ввода.
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
