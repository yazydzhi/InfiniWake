import Foundation

/// Предпочтение языка в настройках.
enum AppLanguagePreference: String, Codable, CaseIterable {
    case system
    case english
    case russian

    var menuTitle: String {
        switch self {
        case .system: return L10n.languageSystem
        case .english: return "English"
        case .russian: return "Русский"
        }
    }
}

/// Фактический язык интерфейса.
enum AppLanguage: String {
    case english
    case russian

    static func resolved(from preference: AppLanguagePreference) -> AppLanguage {
        switch preference {
        case .english:
            return .english
        case .russian:
            return .russian
        case .system:
            return detectSystemLanguage()
        }
    }

    /// Системный язык: русский, если preferredLanguages / Locale начинается с ru.
    private static func detectSystemLanguage() -> AppLanguage {
        for raw in Locale.preferredLanguages {
            let code = raw.lowercased()
            if code.hasPrefix("ru") {
                return .russian
            }
        }
        if let code = Locale.current.language.languageCode?.identifier.lowercased(), code == "ru" {
            return .russian
        }
        return .english
    }
}

/// Строки интерфейса EN/RU.
enum L10n {
    static var language: AppLanguage = .resolved(from: .system)

    private static var isRU: Bool { language == .russian }

    // MARK: - Language picker

    static var languageSystem: String { isRU ? "Как в системе" : "System" }
    static var languageLabel: String { isRU ? "Язык" : "Language" }

    // MARK: - Menu bar

    static func tooltipOn(remaining: String) -> String {
        isRU
            ? "InfiniWake: не засыпать (\(remaining)). Клик — выкл. ПКМ — меню."
            : "InfiniWake: staying awake (\(remaining)). Click to turn off. Right-click for menu."
    }

    static func tooltipOff() -> String {
        isRU
            ? "InfiniWake: sleep как обычно. Клик — вкл. ПКМ — меню."
            : "InfiniWake: normal sleep. Click to turn on. Right-click for menu."
    }

    static func stateOn(remaining: String) -> String {
        isRU ? "Состояние: включено (\(remaining))" : "Status: on (\(remaining))"
    }

    static var stateOff: String { isRU ? "Состояние: выключено" : "Status: off" }
    static var turnOn: String { isRU ? "Включить" : "Turn On" }
    static var turnOff: String { isRU ? "Выключить" : "Turn Off" }
    static var autoOff: String { isRU ? "Авто-выключение" : "Auto-off" }
    static var unlimited: String { isRU ? "∞ бесконечно" : "∞ Unlimited" }

    static func hotkey(_ title: String) -> String {
        isRU ? "Хоткей: \(title)" : "Hotkey: \(title)"
    }

    static var helperOK: String {
        isRU ? "Закрытая крышка: pmset OK" : "Closed lid: pmset OK"
    }

    static var helperNeeded: String {
        isRU ? "Закрытая крышка: нужен helper" : "Closed lid: helper needed"
    }

    static var settings: String { isRU ? "Настройки…" : "Settings…" }
    static func about(_ name: String) -> String { isRU ? "О \(name)…" : "About \(name)…" }
    static func version(_ v: String) -> String { isRU ? "Версия \(v)" : "Version \(v)" }
    static var quit: String { isRU ? "Выйти" : "Quit" }

    static func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return isRU ? "\(minutes)м" : "\(minutes)m"
        }
        let hours = minutes / 60
        let rem = minutes % 60
        if rem == 0 {
            return isRU ? "\(hours)ч" : "\(hours)h"
        }
        return isRU ? "\(hours)ч\(rem)м" : "\(hours)h\(rem)m"
    }

    /// Компактный остаток для менюбара: только часы/минуты, секунды — если меньше минуты.
    /// Суффиксы: `ч`/`м`/`с` или `h`/`m`/`s`.
    static func formatRemaining(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            if minutes > 0 {
                return isRU ? "\(hours)ч\(minutes)м" : "\(hours)h\(minutes)m"
            }
            return isRU ? "\(hours)ч" : "\(hours)h"
        }
        if minutes > 0 {
            return isRU ? "\(minutes)м" : "\(minutes)m"
        }
        return isRU ? "\(seconds)с" : "\(seconds)s"
    }

    static func minutesLabel(_ minutes: Int) -> String {
        isRU ? "\(minutes) мин" : "\(minutes) min"
    }

    // MARK: - Settings

    static var settingsTitle: String {
        isRU ? "\(AppInfo.name) — настройки" : "\(AppInfo.name) — Settings"
    }

    static var autoOffLabel: String { autoOff }
    static var hotkeyLabel: String { isRU ? "Клавиша включения" : "Toggle hotkey" }
    static var ledCheckbox: String {
        isRU
            ? "Лампа Caps Lock (без настоящего CAPS)"
            : "Caps Lock LED (no real CAPS typing)"
    }

    static var iconCheckbox: String {
        isRU ? "Показывать иконку в менюбаре" : "Show menu bar icon"
    }

    static var menuBarIconStyleLabel: String {
        isRU ? "Значок в менюбаре" : "Menu bar icon"
    }

    static func menuBarIconStyleTitle(_ style: MenuBarIconStyle) -> String {
        switch style {
        case .infinity:
            return isRU ? "∞" : "∞"
        case .lamp:
            return isRU ? "Лампа" : "Lamp"
        case .infinityLamp:
            return isRU ? "∞ + лампа" : "∞ + lamp"
        }
    }

    static var loginCheckbox: String {
        isRU ? "Запускать при входе в систему" : "Launch at login"
    }

    static var settingsHint: String {
        isRU
            ? """
            Если хоткей — Caps Lock: ON держит Mac awake, OFF возвращает сон; \
            смена языка через Caps Lock в этом режиме недоступна. \
            Для остальных клавиш Caps Lock остаётся лампой/языком; настоящий CAPS при активном \
            режиме отключён (нужен Accessibility).
            """
            : """
            Caps Lock as hotkey: ON keeps the Mac awake, OFF restores sleep; \
            Caps Lock language switching is unavailable in that mode. \
            For other hotkeys, Caps Lock stays LED/language; real CAPS typing is blocked while \
            keep-awake is on (Accessibility required).
            """
    }

    static var save: String { isRU ? "Сохранить" : "Save" }

    // MARK: - About

    static func aboutBody(version: String) -> String {
        let creator = isRU ? AppInfo.creatorName : AppInfo.creatorNameEN
        if isRU {
            return """
            Версия \(version)

            Keep-awake для macOS: хоткей вместо Caps Lock, лампа Caps Lock как индикатор без настоящего CAPS.

            Создатель: \(creator)
            \(AppInfo.copyright)
            Лицензия: MIT · бесплатно

            \(AppInfo.websiteURL?.absoluteString ?? "")
            """
        }
        return """
        Version \(version)

        macOS keep-awake: hotkey instead of Caps Lock, Caps Lock LED as indicator without real CAPS.

        Author: \(creator)
        \(AppInfo.copyrightEN)
        License: MIT · free

        \(AppInfo.websiteURL?.absoluteString ?? "")
        """
    }

    // MARK: - Alerts

    static var enableFailed: String {
        isRU
            ? "Не удалось включить keep-awake. Установи helper для закрытой крышки (см. README)."
            : "Could not enable keep-awake. Install the closed-lid helper (see README)."
    }

    static var accessibilityTitle: String {
        isRU
            ? "InfiniWake: нужен доступ Accessibility"
            : "InfiniWake: Accessibility access required"
    }

    static var accessibilityBody: String {
        isRU
            ? """
            Чтобы лампа Caps Lock горела без настоящего CAPS-ввода:

            1. Системные настройки → Конфиденциальность и безопасность → Универсальный доступ
            2. Включи InfiniWake (если уже включён — выключи и включи снова)
            3. Полностью выйди из InfiniWake и запусти снова из /Applications

            macOS применяет Accessibility только после перезапуска приложения. \
            Keep-awake уже работает; лампа заработает после перезапуска с доступом.
            """
            : """
            To keep the Caps Lock LED on without real CAPS typing:

            1. System Settings → Privacy & Security → Accessibility
            2. Enable InfiniWake (if already on — toggle it off and on)
            3. Quit InfiniWake completely and reopen it from /Applications

            macOS applies Accessibility only after the app restarts. \
            Keep-awake already works; the LED will work after a restart with access granted.
            """
    }

    static var openSettingsButton: String { isRU ? "Открыть настройки" : "Open Settings" }
    static var quitAndRestartButton: String { isRU ? "Выйти сейчас" : "Quit Now" }
    static var laterButton: String { isRU ? "Позже" : "Later" }
}
