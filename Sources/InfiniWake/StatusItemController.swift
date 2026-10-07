import AppKit

/// Иконка в менюбаре: ∞ / лампа / ∞+лампа.
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
    private var iconStyle: MenuBarIconStyle = .infinity

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
        helperOK: Bool,
        iconStyle: MenuBarIconStyle
    ) {
        self.isEnabled = enabled
        self.remainingText = remainingText
        self.autoOffMinutes = autoOffMinutes
        self.hotkeyTitle = hotkeyTitle
        self.helperOK = helperOK
        self.iconStyle = iconStyle
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
        switch iconStyle {
        case .infinity:
            // Для ∞ оставляем текст таймера, когда режим включён
            let title: String
            let alpha: CGFloat
            if isEnabled {
                title = remainingText
                alpha = 1.0
            } else if autoOffMinutes > 0 {
                title = L10n.formatMinutes(autoOffMinutes)
                alpha = 0.35
            } else {
                title = "∞"
                alpha = 0.35
            }
            button.image = makeCountdownOrInfinity(text: title, alpha: alpha, emphasized: isEnabled)
        case .lamp:
            button.image = MenuBarIconArt.image(style: .lamp, lit: isEnabled)
        case .infinityLamp:
            let topText = remainingText == "∞" ? nil : remainingText
            button.image = MenuBarIconArt.image(
                style: .infinityLamp,
                lit: isEnabled,
                infinityLampTopText: topText
            )
        }
        button.imagePosition = .imageOnly
        button.toolTip = isEnabled ? L10n.tooltipOn(remaining: remainingText) : L10n.tooltipOff()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let state = NSMenuItem(
            title: isEnabled ? L10n.stateOn(remaining: remainingText) : L10n.stateOff,
            action: nil,
            keyEquivalent: ""
        )
        state.isEnabled = false
        menu.addItem(state)

        let toggle = NSMenuItem(
            title: isEnabled ? L10n.turnOff : L10n.turnOn,
            action: #selector(toggleClicked),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)

        menu.addItem(NSMenuItem.separator())

        let timerHeader = NSMenuItem(title: L10n.autoOff, action: nil, keyEquivalent: "")
        timerHeader.isEnabled = false
        menu.addItem(timerHeader)

        for minutes in [0, 15, 30, 60, 120, 240, 480] {
            let title = minutes == 0 ? L10n.unlimited : L10n.formatMinutes(minutes)
            let item = NSMenuItem(title: title, action: #selector(autoOffClicked(_:)), keyEquivalent: "")
            item.target = self
            item.tag = minutes
            item.state = (autoOffMinutes == minutes) ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let hotkey = NSMenuItem(title: L10n.hotkey(hotkeyTitle), action: nil, keyEquivalent: "")
        hotkey.isEnabled = false
        menu.addItem(hotkey)

        let helper = NSMenuItem(
            title: helperOK ? L10n.helperOK : L10n.helperNeeded,
            action: nil,
            keyEquivalent: ""
        )
        helper.isEnabled = false
        menu.addItem(helper)

        menu.addItem(NSMenuItem.separator())

        let settings = NSMenuItem(title: L10n.settings, action: #selector(settingsClicked), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let about = NSMenuItem(
            title: L10n.about(AppInfo.name),
            action: #selector(aboutClicked),
            keyEquivalent: ""
        )
        about.target = self
        menu.addItem(about)

        let version = NSMenuItem(
            title: L10n.version(AppInfo.displayVersion),
            action: nil,
            keyEquivalent: ""
        )
        version.isEnabled = false
        menu.addItem(version)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: L10n.quit, action: #selector(quitClicked), keyEquivalent: "q")
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

    private func makeCountdownOrInfinity(text: String, alpha: CGFloat, emphasized: Bool) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: emphasized ? .semibold : .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor.withAlphaComponent(alpha)
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let width = max(ceil(size.width) + 4, 18)
        let height: CGFloat = 18
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let rect = NSRect(
                x: (width - size.width) / 2,
                y: (height - size.height) / 2,
                width: size.width,
                height: size.height
            )
            (text as NSString).draw(in: rect, withAttributes: attributes)
            return true
        }
        image.isTemplate = true
        return image
    }
}
