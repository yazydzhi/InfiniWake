import AppKit

/// Окно «О программе» с версией, автором и иконкой.
enum AboutWindow {
    static func show() {
        let alert = NSAlert()
        alert.messageText = AppInfo.name
        alert.informativeText = """
        Версия \(AppInfo.displayVersion)

        Keep-awake для macOS: хоткей вместо Caps Lock, лампа Caps Lock как индикатор без настоящего CAPS.

        Создатель: \(AppInfo.creatorName)
        \(AppInfo.copyright)
        Лицензия: MIT · бесплатно

        \(AppInfo.websiteURL?.absoluteString ?? "")
        """
        alert.alertStyle = .informational
        if let icon = NSApp.applicationIconImage ?? NSImage(named: NSImage.applicationIconName) {
            alert.icon = icon
        } else if let path = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
                  let image = NSImage(contentsOfFile: path) {
            alert.icon = image
        }
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
