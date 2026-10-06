import Foundation

/// Версия и метаданные приложения.
enum AppInfo {
    static let name = "InfiniWake"
    static let version = "1.1.0"
    static let build = "2"
    static let creatorName = "Владимир Языджи"
    static let creatorNameEN = "Vladimir Yazydzhi"
    static let creatorHandle = "azg"
    static let copyright = "© 2026 Владимир Языджи"
    static let copyrightEN = "© 2026 Vladimir Yazydzhi"
    static let websiteURL = URL(string: "https://github.com/yazydzhi/InfiniWake")
    static let bundleID = "com.azg.InfiniWake"

    static var localizedCreator: String {
        L10n.language == .russian ? creatorName : creatorNameEN
    }

    static var shortVersionLabel: String {
        "\(name) \(version)"
    }

    static var aboutText: String {
        """
        \(name) \(version) (\(build))

        Держит Mac бодрствующим. Caps Lock — только лампа-индикатор, без настоящего CAPS.

        Создатель: \(creatorName) (@\(creatorHandle))
        \(copyright)
        """
    }

    /// Версия из Info.plist, если собрано в .app; иначе константы.
    static var displayVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildNum = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return "\(short ?? version) (\(buildNum ?? build))"
    }
}
