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
    /// Язык интерфейса: system / english / russian.
    var language: AppLanguagePreference = .system

    static let storageKey = "infiniwake.settings"

    enum CodingKeys: String, CodingKey {
        case autoOffMinutes
        case hotkeyKeyCode
        case hotkeyModifiers
        case showMenuBarIcon
        case useCapsLockLED
        case launchAtLogin
        case language
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        autoOffMinutes = try container.decodeIfPresent(Int.self, forKey: .autoOffMinutes) ?? 0
        hotkeyKeyCode = try container.decodeIfPresent(UInt16.self, forKey: .hotkeyKeyCode) ?? 0x76
        hotkeyModifiers = try container.decodeIfPresent(UInt32.self, forKey: .hotkeyModifiers) ?? 0
        showMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? true
        useCapsLockLED = try container.decodeIfPresent(Bool.self, forKey: .useCapsLockLED) ?? true
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        language = try container.decodeIfPresent(AppLanguagePreference.self, forKey: .language) ?? .system
    }

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
