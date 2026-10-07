import AppKit
import Carbon.HIToolbox

/// Окно настроек InfiniWake — изменения применяются сразу.
final class SettingsWindowController: NSWindowController {
    private var current: InfiniWakeSettings
    private let onChange: (InfiniWakeSettings) -> Void
    /// Блокирует автоприменение во время программной загрузки значений.
    private var isLoadingValues = false

    private let languagePopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let autoOffPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let hotkeyPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let ledCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let iconCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let loginCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let hintLabel = NSTextField(wrappingLabelWithString: "")
    private let footerLabel = NSTextField(labelWithString: "")

    private var languageLabelRow: NSStackView?
    private var autoOffLabelRow: NSStackView?
    private var hotkeyLabelRow: NSStackView?
    private let iconStylePickerHost = NSView()
    private let iconStylePickerStack = NSStackView()
    private var iconStylePickerButtons: [MenuBarIconStyle: NSButton] = [:]
    private var selectedIconStyle: MenuBarIconStyle = .infinity

    private let iconStyleOptions = MenuBarIconStyle.allCases
    private let languageOptions: [AppLanguagePreference] = [.system, .english, .russian]
    private let hotkeyOptions = HotKeyOption.all
    private let autoOffOptions = [0, 15, 30, 60, 120, 240, 480]

    init(settings: InfiniWakeSettings, onSave: @escaping (InfiniWakeSettings) -> Void) {
        self.current = settings
        self.onChange = onSave
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 480),
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

    /// После смены языка в live-режиме — обновить подписи, не сбрасывая выбор.
    func refreshAfterLanguageChange(_ settings: InfiniWakeSettings) {
        current = settings
        applyLocalizedTitles()
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
        languagePopUp.target = self
        languagePopUp.action = #selector(settingChanged(_:))

        let autoRow = labeled("", autoOffPopUp)
        autoOffLabelRow = autoRow
        stack.addArrangedSubview(autoRow)
        autoOffPopUp.target = self
        autoOffPopUp.action = #selector(settingChanged(_:))

        let hotRow = labeled("", hotkeyPopUp)
        hotkeyLabelRow = hotRow
        stack.addArrangedSubview(hotRow)
        for option in hotkeyOptions {
            hotkeyPopUp.addItem(withTitle: option.title)
        }
        hotkeyPopUp.target = self
        hotkeyPopUp.action = #selector(settingChanged(_:))

        ledCheck.target = self
        ledCheck.action = #selector(settingChanged(_:))
        iconCheck.target = self
        iconCheck.action = #selector(settingChanged(_:))
        stack.addArrangedSubview(ledCheck)
        stack.addArrangedSubview(iconCheck)

        iconStylePickerHost.wantsLayer = true
        iconStylePickerHost.layer?.cornerRadius = 8
        iconStylePickerHost.layer?.borderWidth = 1
        iconStylePickerHost.layer?.borderColor = NSColor.separatorColor.cgColor
        iconStylePickerHost.translatesAutoresizingMaskIntoConstraints = false

        iconStylePickerStack.orientation = .horizontal
        iconStylePickerStack.spacing = 0
        iconStylePickerStack.distribution = .fillEqually
        iconStylePickerStack.translatesAutoresizingMaskIntoConstraints = false
        iconStylePickerHost.addSubview(iconStylePickerStack)
        let previewSize = MenuBarIconArt.settingsPreviewSize

        for (index, style) in iconStyleOptions.enumerated() {
            let button = NSButton(title: "", target: self, action: #selector(iconStylePickerClicked(_:)))
            button.isBordered = false
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleNone
            button.tag = index
            button.translatesAutoresizingMaskIntoConstraints = false
            iconStylePickerButtons[style] = button
            button.widthAnchor.constraint(equalToConstant: previewSize.width).isActive = true
            iconStylePickerStack.addArrangedSubview(button)
            if index > 0 {
                let divider = NSBox()
                divider.boxType = .separator
                divider.translatesAutoresizingMaskIntoConstraints = false
                button.addSubview(divider)
                NSLayoutConstraint.activate([
                    divider.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                    divider.topAnchor.constraint(equalTo: button.topAnchor, constant: 6),
                    divider.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -6),
                    divider.widthAnchor.constraint(equalToConstant: 1)
                ])
            }
        }

        stack.addArrangedSubview(iconStylePickerHost)
        NSLayoutConstraint.activate([
            iconStylePickerHost.heightAnchor.constraint(equalToConstant: previewSize.height + 4),
            iconStylePickerHost.widthAnchor.constraint(
                equalToConstant: previewSize.width * CGFloat(iconStyleOptions.count) + 2
            ),
            iconStylePickerStack.topAnchor.constraint(equalTo: iconStylePickerHost.topAnchor, constant: 1),
            iconStylePickerStack.leadingAnchor.constraint(equalTo: iconStylePickerHost.leadingAnchor, constant: 1),
            iconStylePickerStack.trailingAnchor.constraint(equalTo: iconStylePickerHost.trailingAnchor, constant: -1),
            iconStylePickerStack.bottomAnchor.constraint(equalTo: iconStylePickerHost.bottomAnchor, constant: -1)
        ])

        loginCheck.target = self
        loginCheck.action = #selector(settingChanged(_:))
        stack.addArrangedSubview(loginCheck)

        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(hintLabel)

        footerLabel.font = NSFont.systemFont(ofSize: 10)
        footerLabel.textColor = .tertiaryLabelColor
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(footerLabel)
        NSLayoutConstraint.activate([
            footerLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            footerLabel.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -20),
            footerLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16)
        ])
    }

    @objc private func settingChanged(_ sender: Any?) {
        guard !isLoadingValues else { return }
        applyCurrentValues()
    }

    @objc private func iconStylePickerClicked(_ sender: NSButton) {
        let idx = max(0, min(sender.tag, iconStyleOptions.count - 1))
        selectedIconStyle = iconStyleOptions[idx]
        refreshIconStyleSelection()
        guard !isLoadingValues else { return }
        applyCurrentValues()
    }

    /// Превью в настройках: «горит» только у выбранного сегмента.
    private func iconStylePreviewImage(for style: MenuBarIconStyle) -> NSImage {
        let lit = style == selectedIconStyle
        return MenuBarIconArt.image(style: style, lit: lit, forPreview: true)
    }

    private func refreshIconStyleSelection() {
        for (index, style) in iconStyleOptions.enumerated() {
            guard let button = iconStylePickerButtons[style] else { continue }
            let selected = style == selectedIconStyle
            button.image = iconStylePreviewImage(for: style)
            button.toolTip = L10n.menuBarIconStyleTitle(style)
            button.wantsLayer = true
            if selected {
                button.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.22).cgColor
                button.layer?.cornerRadius = index == 0 ? 7 : (index == iconStyleOptions.count - 1 ? 7 : 0)
                if index == 0 {
                    button.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
                } else if index == iconStyleOptions.count - 1 {
                    button.layer?.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
                } else {
                    button.layer?.cornerRadius = 0
                }
            } else {
                button.layer?.backgroundColor = NSColor.clear.cgColor
                button.layer?.cornerRadius = 0
            }
        }
    }

    private func applyLocalizedTitles() {
        isLoadingValues = true
        defer { isLoadingValues = false }

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
        footerLabel.stringValue = "\(AppInfo.name) \(AppInfo.displayVersion) · \(AppInfo.localizedCreator)"
        refreshIconStyleSelection()
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
        isLoadingValues = true
        defer { isLoadingValues = false }

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
        } else if let f4 = hotkeyOptions.firstIndex(where: { $0.keyCode == UInt16(kVK_F4) && $0.modifiers == 0 }) {
            hotkeyPopUp.selectItem(at: f4)
        } else {
            hotkeyPopUp.selectItem(at: 0)
        }

        ledCheck.state = current.useCapsLockLED ? .on : .off
        iconCheck.state = current.showMenuBarIcon ? .on : .off
        selectedIconStyle = current.menuBarIconStyle
        refreshIconStyleSelection()
        loginCheck.state = current.launchAtLogin ? .on : .off
    }

    private func applyCurrentValues() {
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
        updated.menuBarIconStyle = selectedIconStyle
        updated.launchAtLogin = loginCheck.state == .on

        current = updated
        onChange(updated)
    }
}
