import AppKit

/// Окно «О программе» с версией, автором и иконкой.
enum AboutWindow {
    static func show() {
        let alert = NSAlert()
        alert.messageText = AppInfo.name
        alert.informativeText = L10n.aboutBody(version: AppInfo.displayVersion)
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
