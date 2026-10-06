import AppKit
import Carbon.HIToolbox

/// Простое окно настроек InfiniWake.
final class SettingsWindowController: NSWindowController {
    private var current: InfiniWakeSettings
    private let onSave: (InfiniWakeSettings) -> Void

    private let autoOffPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let hotkeyPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let ledCheck = NSButton(
        checkboxWithTitle: "Лампа Caps Lock (без настоящего CAPS)",
        target: nil,
        action: nil
    )
    private let iconCheck = NSButton(checkboxWithTitle: "Показывать иконку в менюбаре", target: nil, action: nil)
    private let loginCheck = NSButton(checkboxWithTitle: "Запускать при входе в систему", target: nil, action: nil)

    private let hotkeyOptions: [(title: String, code: UInt16, modifiers: UInt32)] = [
        ("F4", UInt16(kVK_F4), 0),
        ("F5", UInt16(kVK_F5), 0),
        ("F6", UInt16(kVK_F6), 0),
        ("F7", UInt16(kVK_F7), 0),
        ("F8", UInt16(kVK_F8), 0),
        ("⌃F4", UInt16(kVK_F4), UInt32(controlKey)),
        ("⌥F4", UInt16(kVK_F4), UInt32(optionKey)),
        ("⌘⇧L", UInt16(kVK_ANSI_L), UInt32(cmdKey | shiftKey))
    ]

    private let autoOffOptions = [0, 15, 30, 60, 120, 240, 480]

    init(settings: InfiniWakeSettings, onSave: @escaping (InfiniWakeSettings) -> Void) {
        self.current = settings
        self.onSave = onSave
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(AppInfo.name) — настройки"
        window.center()
        super.init(window: window)
        buildUI()
        loadValues()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateSettings(_ settings: InfiniWakeSettings) {
        current = settings
        loadValues()
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20)
        ])

        stack.addArrangedSubview(labeled("Авто-выключение", autoOffPopUp))
        for minutes in autoOffOptions {
            let title = minutes == 0 ? "∞ бесконечно" : "\(minutes) мин"
            autoOffPopUp.addItem(withTitle: title)
        }

        stack.addArrangedSubview(labeled("Клавиша включения", hotkeyPopUp))
        for option in hotkeyOptions {
            hotkeyPopUp.addItem(withTitle: option.title)
        }

        ledCheck.target = self
        iconCheck.target = self
        loginCheck.target = self
        stack.addArrangedSubview(ledCheck)
        stack.addArrangedSubview(iconCheck)
        stack.addArrangedSubview(loginCheck)

        let hint = NSTextField(wrappingLabelWithString: """
        Caps Lock не переключает режим — только лампа. Пока лампа горит, настоящий CAPS \
        отключён (нужен Accessibility). Смена языка через Caps Lock сохраняется. \
        Вкл/выкл — хоткей или клик по иконке.
        """)
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        stack.addArrangedSubview(hint)

        let footer = NSTextField(labelWithString: "\(AppInfo.name) \(AppInfo.displayVersion) · \(AppInfo.creatorName)")
        footer.font = NSFont.systemFont(ofSize: 10)
        footer.textColor = .tertiaryLabelColor

        let save = NSButton(title: "Сохранить", target: self, action: #selector(saveClicked))
        save.keyEquivalent = "\r"
        let buttons = NSStackView(views: [footer, NSView(), save])
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 8
        buttons.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(buttons)
        NSLayoutConstraint.activate([
            buttons.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16)
        ])
    }

    private func labeled(_ title: String, _ control: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.boldSystemFont(ofSize: 12)
        let row = NSStackView(views: [label, control])
        row.orientation = .vertical
        row.alignment = .leading
        row.spacing = 4
        control.translatesAutoresizingMaskIntoConstraints = false
        control.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        return row
    }

    private func loadValues() {
        if let idx = autoOffOptions.firstIndex(of: current.autoOffMinutes) {
            autoOffPopUp.selectItem(at: idx)
        } else {
            autoOffPopUp.selectItem(at: 0)
        }

        if let idx = hotkeyOptions.firstIndex(where: {
            $0.code == current.hotkeyKeyCode && $0.modifiers == current.hotkeyModifiers
        }) {
            hotkeyPopUp.selectItem(at: idx)
        } else {
            hotkeyPopUp.selectItem(at: 0)
        }

        ledCheck.state = current.useCapsLockLED ? .on : .off
        iconCheck.state = current.showMenuBarIcon ? .on : .off
        loginCheck.state = current.launchAtLogin ? .on : .off
    }

    @objc private func saveClicked() {
        var updated = current
        let autoIdx = max(0, autoOffPopUp.indexOfSelectedItem)
        updated.autoOffMinutes = autoOffOptions[autoIdx]

        let hotIdx = max(0, hotkeyPopUp.indexOfSelectedItem)
        let hot = hotkeyOptions[hotIdx]
        updated.hotkeyKeyCode = hot.code
        updated.hotkeyModifiers = hot.modifiers

        updated.useCapsLockLED = ledCheck.state == .on
        updated.showMenuBarIcon = iconCheck.state == .on
        updated.launchAtLogin = loginCheck.state == .on

        onSave(updated)
        window?.close()
    }
}
