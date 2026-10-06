import Foundation

/// Пользовательские настройки InfiniWake.
struct InfiniWakeSettings: Codable, Equatable {
    /// Длительность авто-выключения в минутах. 0 = бесконечно (∞).
    var autoOffMinutes: Int = 0
    /// Карбон-код клавиши хоткея (по умолчанию F4 = 0x76).
    var hotkeyKeyCode: UInt16 = 0x76
    /// Модификаторы Carbon (0 = без модификаторов).
    var hotkeyModifiers: UInt32 = 0
    /// Показывать иконку в менюбаре.
    var showMenuBarIcon: Bool = true
    /// Подсвечивать Caps Lock LED пока keep-awake включён.
    var useCapsLockLED: Bool = true
    /// Автозапуск при входе в систему.
    var launchAtLogin: Bool = false

    static let storageKey = "infiniwake.settings"

    static func load() -> InfiniWakeSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(InfiniWakeSettings.self, from: data) else {
            return InfiniWakeSettings()
        }
        return decoded
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
