/// Store-сборка (флаг APPSTORE) работает в App Sandbox: без лампы Caps Lock, helper и Accessibility.
/// Без фильтра CAPS (CGEventTap, нужен Accessibility) лампа включила бы настоящий капс при печати.
enum AppFlavor {
    #if APPSTORE
    static let hasCapsLockLED = false
    #else
    static let hasCapsLockLED = true
    #endif
}
