import AppKit

/// Иконка в менюбаре: ∞ когда keep-awake без таймера, оставшееся время, полупрозрачная когда выкл.
final class StatusItemController {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    var onToggle: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onAbout: (() -> Void)?
    var onQuit: (() -> Void)?
    var onSelectAutoOff: ((Int) -> Void)?

    private var isEnabled = false
    private var remainingText = "∞"
    private var autoOffMinutes = 0
    private var hotkeyTitle = "F4"
    private var helperOK = false

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        rebuildMenu()
        statusItem.menu = nil
        render()
    }

    func setVisible(_ visible: Bool) {
        statusItem.isVisible = visible
    }

    func update(
        enabled: Bool,
        remainingText: String,
        autoOffMinutes: Int,
        hotkeyTitle: String,
        helperOK: Bool
    ) {
        self.isEnabled = enabled
        self.remainingText = remainingText
        self.autoOffMinutes = autoOffMinutes
        self.hotkeyTitle = hotkeyTitle
        self.helperOK = helperOK
        render()
        rebuildMenu()
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            onToggle?()
        }
    }

    private func render() {
        guard let button = statusItem.button else { return }
        let title: String
        let alpha: CGFloat
        if isEnabled {
            title = remainingText
            alpha = 1.0
        } else if autoOffMinutes > 0 {
            title = formatMinutes(autoOffMinutes)
            alpha = 0.35
        } else {
            title = "∞"
            alpha = 0.35
        }

        let image = Self.makeIcon(text: title, alpha: alpha, emphasized: isEnabled)
        button.image = image
        button.imagePosition = .imageOnly
        button.toolTip = isEnabled
            ? "InfiniWake: не засыпать (\(remainingText)). Клик — выкл. ПКМ — меню."
            : "InfiniWake: sleep как обычно. Клик — вкл. ПКМ — меню."
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let state = NSMenuItem(
            title: isEnabled ? "Состояние: включено (\(remainingText))" : "Состояние: выключено",
            action: nil,
            keyEquivalent: ""
        )
        state.isEnabled = false
        menu.addItem(state)

        let toggle = NSMenuItem(
            title: isEnabled ? "Выключить" : "Включить",
            action: #selector(toggleClicked),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)

        menu.addItem(NSMenuItem.separator())

        let timerHeader = NSMenuItem(title: "Авто-выключение", action: nil, keyEquivalent: "")
        timerHeader.isEnabled = false
        menu.addItem(timerHeader)

        for minutes in [0, 15, 30, 60, 120, 240, 480] {
            let title = minutes == 0 ? "∞ бесконечно" : formatMinutes(minutes)
            let item = NSMenuItem(title: title, action: #selector(autoOffClicked(_:)), keyEquivalent: "")
            item.target = self
            item.tag = minutes
            item.state = (autoOffMinutes == minutes) ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let hotkey = NSMenuItem(
            title: "Хоткей: \(hotkeyTitle)",
            action: nil,
            keyEquivalent: ""
        )
        hotkey.isEnabled = false
        menu.addItem(hotkey)

        let helper = NSMenuItem(
            title: helperOK ? "Закрытая крышка: pmset OK" : "Закрытая крышка: нужен helper",
            action: nil,
            keyEquivalent: ""
        )
        helper.isEnabled = false
        menu.addItem(helper)

        menu.addItem(NSMenuItem.separator())

        let settings = NSMenuItem(title: "Настройки…", action: #selector(settingsClicked), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let about = NSMenuItem(
            title: "О \(AppInfo.name)…",
            action: #selector(aboutClicked),
            keyEquivalent: ""
        )
        about.target = self
        menu.addItem(about)

        let version = NSMenuItem(
            title: "Версия \(AppInfo.displayVersion)",
            action: nil,
            keyEquivalent: ""
        )
        version.isEnabled = false
        menu.addItem(version)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: "Выйти", action: #selector(quitClicked), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func toggleClicked() { onToggle?() }
    @objc private func settingsClicked() { onOpenSettings?() }
    @objc private func aboutClicked() { onAbout?() }
    @objc private func quitClicked() { onQuit?() }

    @objc private func autoOffClicked(_ sender: NSMenuItem) {
        onSelectAutoOff?(sender.tag)
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)м" }
        let hours = minutes / 60
        let rem = minutes % 60
        if rem == 0 { return "\(hours)ч" }
        return "\(hours)ч\(rem)м"
    }

    private static func makeIcon(text: String, alpha: CGFloat, emphasized: Bool) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: emphasized ? .semibold : .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor.withAlphaComponent(alpha)
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let width = max(ceil(size.width) + 4, 18)
        let height: CGFloat = 18
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        let rect = NSRect(
            x: (width - size.width) / 2,
            y: (height - size.height) / 2,
            width: size.width,
            height: size.height
        )
        (text as NSString).draw(in: rect, withAttributes: attributes)
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
