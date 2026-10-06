import AppKit
import Carbon.HIToolbox

/// Простое окно настроек InfiniWake.
final class SettingsWindowController: NSWindowController {
    private var current: InfiniWakeSettings
    private let onSave: (InfiniWakeSettings) -> Void

    private let languagePopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let autoOffPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let hotkeyPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let ledCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let iconCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let loginCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let hintLabel = NSTextField(wrappingLabelWithString: "")
    private let footerLabel = NSTextField(labelWithString: "")
    private let saveButton = NSButton(title: "", target: nil, action: nil)

    private var languageLabelRow: NSStackView?
    private var autoOffLabelRow: NSStackView?
    private var hotkeyLabelRow: NSStackView?

    private let languageOptions: [AppLanguagePreference] = [.system, .english, .russian]

    private let hotkeyOptions = HotKeyOption.all

    private let autoOffOptions = [0, 15, 30, 60, 120, 240, 480]

    init(settings: InfiniWakeSettings, onSave: @escaping (InfiniWakeSettings) -> Void) {
        self.current = settings
        self.onSave = onSave
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        super.init(window: window)
        buildUI()
        applyLocalizedTitles()
        loadValues()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateSettings(_ settings: InfiniWakeSettings) {
        current = settings
        applyLocalizedTitles()
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

        let langRow = labeled("", languagePopUp)
        languageLabelRow = langRow
        stack.addArrangedSubview(langRow)
        for option in languageOptions {
            languagePopUp.addItem(withTitle: option.menuTitle)
        }

        let autoRow = labeled("", autoOffPopUp)
        autoOffLabelRow = autoRow
        stack.addArrangedSubview(autoRow)

        let hotRow = labeled("", hotkeyPopUp)
        hotkeyLabelRow = hotRow
        stack.addArrangedSubview(hotRow)
        for option in hotkeyOptions {
            hotkeyPopUp.addItem(withTitle: option.title)
        }

        stack.addArrangedSubview(ledCheck)
        stack.addArrangedSubview(iconCheck)
        stack.addArrangedSubview(loginCheck)

        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(hintLabel)

        footerLabel.font = NSFont.systemFont(ofSize: 10)
        footerLabel.textColor = .tertiaryLabelColor

        saveButton.target = self
        saveButton.action = #selector(saveClicked)
        saveButton.keyEquivalent = "\r"
        let buttons = NSStackView(views: [footerLabel, NSView(), saveButton])
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

    private func applyLocalizedTitles() {
        window?.title = L10n.settingsTitle
        setRowTitle(languageLabelRow, L10n.languageLabel)
        setRowTitle(autoOffLabelRow, L10n.autoOffLabel)
        setRowTitle(hotkeyLabelRow, L10n.hotkeyLabel)

        let selectedLang = languagePopUp.indexOfSelectedItem
        languagePopUp.removeAllItems()
        for option in languageOptions {
            languagePopUp.addItem(withTitle: option.menuTitle)
        }
        if selectedLang >= 0 {
            languagePopUp.selectItem(at: selectedLang)
        }

        let selectedAuto = autoOffPopUp.indexOfSelectedItem
        autoOffPopUp.removeAllItems()
        for minutes in autoOffOptions {
            let title = minutes == 0 ? L10n.unlimited : L10n.minutesLabel(minutes)
            autoOffPopUp.addItem(withTitle: title)
        }
        if selectedAuto >= 0 {
            autoOffPopUp.selectItem(at: selectedAuto)
        }

        ledCheck.title = L10n.ledCheckbox
        iconCheck.title = L10n.iconCheckbox
        loginCheck.title = L10n.loginCheckbox
        hintLabel.stringValue = L10n.settingsHint
        saveButton.title = L10n.save
        footerLabel.stringValue = "\(AppInfo.name) \(AppInfo.displayVersion) · \(AppInfo.localizedCreator)"
    }

    private func setRowTitle(_ row: NSStackView?, _ title: String) {
        guard let label = row?.arrangedSubviews.first as? NSTextField else { return }
        label.stringValue = title
    }

    private func labeled(_ title: String, _ control: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.boldSystemFont(ofSize: 12)
        let row = NSStackView(views: [label, control])
        row.orientation = .vertical
        row.alignment = .leading
        row.spacing = 4
        control.translatesAutoresizingMaskIntoConstraints = false
        control.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
        return row
    }

    private func loadValues() {
        if let idx = languageOptions.firstIndex(of: current.language) {
            languagePopUp.selectItem(at: idx)
        } else {
            languagePopUp.selectItem(at: 0)
        }

        if let idx = autoOffOptions.firstIndex(of: current.autoOffMinutes) {
            autoOffPopUp.selectItem(at: idx)
        } else {
            autoOffPopUp.selectItem(at: 0)
        }

        if let idx = hotkeyOptions.firstIndex(where: {
            $0.keyCode == current.hotkeyKeyCode && $0.modifiers == current.hotkeyModifiers
        }) {
            hotkeyPopUp.selectItem(at: idx)
        } else {
            // F4 по умолчанию, если сохранённый хоткей больше не в списке
            if let f4 = hotkeyOptions.firstIndex(where: { $0.keyCode == UInt16(kVK_F4) && $0.modifiers == 0 }) {
                hotkeyPopUp.selectItem(at: f4)
            } else {
                hotkeyPopUp.selectItem(at: 0)
            }
        }

        ledCheck.state = current.useCapsLockLED ? .on : .off
        iconCheck.state = current.showMenuBarIcon ? .on : .off
        loginCheck.state = current.launchAtLogin ? .on : .off
    }

    @objc private func saveClicked() {
        var updated = current
        let langIdx = max(0, languagePopUp.indexOfSelectedItem)
        updated.language = languageOptions[langIdx]

        let autoIdx = max(0, autoOffPopUp.indexOfSelectedItem)
        updated.autoOffMinutes = autoOffOptions[autoIdx]

        let hotIdx = max(0, hotkeyPopUp.indexOfSelectedItem)
        let hot = hotkeyOptions[min(hotIdx, hotkeyOptions.count - 1)]
        updated.hotkeyKeyCode = hot.keyCode
        updated.hotkeyModifiers = hot.modifiers

        updated.useCapsLockLED = ledCheck.state == .on
        updated.showMenuBarIcon = iconCheck.state == .on
        updated.launchAtLogin = loginCheck.state == .on

        onSave(updated)
        window?.close()
    }
}
