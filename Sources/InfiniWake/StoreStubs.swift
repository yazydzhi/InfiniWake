#if APPSTORE
import Foundation

// Заглушки с тем же API, что у вырезанных из Store-сборки типов: контроллер остаётся общим для обеих сборок.
// Лампа Caps Lock в Store-версии выключена (AppFlavor.hasCapsLockLED), поэтому ни один метод ничего не делает.

final class CapsLockLED {
    func isOn() -> Bool { false }
    static func sharedQuickRead() -> Bool { false }
    func setOn(_ on: Bool, verify: Bool = false) -> Bool { false }
    func forceOn() -> Bool { false }
}

final class CapsLockAlphaFilter {
    var onCapsLockKey: (() -> Void)?
    var isTrusted: Bool { false }
    func openAccessibilitySettings() {}
    func promptSystemTrustDialogOnce() -> Bool { false }
    func setFilteringEnabled(_ enabled: Bool) {}
    func stop() {}
    func ensureTapInstalled() -> Bool { false }
}

enum CapsLockLEDDriverFix {
    static func ensureBuiltInKeyboardLEDPassthrough() -> Bool { false }
}

enum SecureInputStateReader {
    static func isSecureEventInputEnabled() -> Bool { false }
}

final class SecureInputFocusMonitor {
    init(onChange: @escaping () -> Void) {}
    func start() {}
    func stop() {}
}
#endif
