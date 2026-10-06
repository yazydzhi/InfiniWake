import AppKit
import ServiceManagement

/// Центральный контроллер: состояние keep-awake, LED, хоткей, таймер, UI.
final class InfiniWakeController {
    private var settings: InfiniWakeSettings
    private let sleepGuard = SleepGuard()
    private let capsLED = CapsLockLED()
    private let capsFilter = CapsLockAlphaFilter()
    private let hotKey = HotKeyManager()
    private let statusItem = StatusItemController()
    private var settingsWindow: SettingsWindowController?

    private var isEnabled = false
    private var deadline: Date?
    private var tickTimer: Timer?
    private var ledSyncTimer: Timer?

    init() {
        settings = InfiniWakeSettings.load()
    }

    func start() {
        statusItem.onToggle = { [weak self] in self?.toggle() }
        statusItem.onOpenSettings = { [weak self] in self?.openSettings() }
        statusItem.onAbout = { AboutWindow.show() }
        statusItem.onQuit = { NSApp.terminate(nil) }
        statusItem.onSelectAutoOff = { [weak self] minutes in
            self?.setAutoOffMinutes(minutes)
        }

        hotKey.onToggle = { [weak self] in self?.toggle() }
        hotKey.register(keyCode: settings.hotkeyKeyCode, modifiers: settings.hotkeyModifiers)

        applyLaunchAtLogin()
        statusItem.setVisible(settings.showMenuBarIcon)
        refreshUI()

        // Поддерживаем LED, пока режим включён — Caps Lock остаётся только индикатором
        ledSyncTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            self?.syncCapsLockLED()
        }
    }

    func shutdown() {
        tickTimer?.invalidate()
        ledSyncTimer?.invalidate()
        capsFilter.stop()
        if isEnabled {
            _ = sleepGuard.disable()
            if settings.useCapsLockLED {
                _ = capsLED.setOn(false)
            }
        }
        hotKey.unregister()
    }

    func toggle() {
        if isEnabled {
            disable()
        } else {
            enable()
        }
    }

    func enable() {
        guard !isEnabled else { return }
        guard sleepGuard.enable() else {
            showAlert(
                title: "InfiniWake",
                message: sleepGuard.lastError
                    ?? "Не удалось включить keep-awake. Установи helper для закрытой крышки (см. README)."
            )
            refreshUI()
            return
        }

        isEnabled = true
        restartDeadline()
        applyCapsLockIndicator(active: true)
        // При закрытой крышке можно гасить дисплей — работа продолжается
        if sleepGuard.activeMode == .pmset {
            sleepGuard.sleepDisplayIfNeeded()
        }
        startTicker()
        refreshUI()
    }

    func disable() {
        guard isEnabled else { return }
        isEnabled = false
        deadline = nil
        tickTimer?.invalidate()
        tickTimer = nil
        _ = sleepGuard.disable()
        applyCapsLockIndicator(active: false)
        refreshUI()
    }

    func applySettings(_ newSettings: InfiniWakeSettings) {
        let wasEnabled = isEnabled
        settings = newSettings
        settings.save()

        hotKey.register(keyCode: settings.hotkeyKeyCode, modifiers: settings.hotkeyModifiers)
        statusItem.setVisible(settings.showMenuBarIcon)
        applyLaunchAtLogin()

        if wasEnabled {
            restartDeadline()
            applyCapsLockIndicator(active: true)
        } else {
            applyCapsLockIndicator(active: false)
        }
        refreshUI()
    }

    /// LED + фильтр «не настоящий CAPS». Без Accessibility лампу не зажигаем.
    private func applyCapsLockIndicator(active: Bool) {
        guard active, settings.useCapsLockLED else {
            capsFilter.setFilteringEnabled(false)
            _ = capsLED.setOn(false)
            return
        }

        if !capsFilter.isTrusted {
            _ = capsFilter.requestTrustIfNeeded()
        }

        if capsFilter.ensureTapInstalled() {
            capsFilter.setFilteringEnabled(true)
            _ = capsLED.setOn(true)
            return
        }

        // Без Accessibility нельзя безопасно держать LED — будет настоящий CAPS
        capsFilter.setFilteringEnabled(false)
        _ = capsLED.setOn(false)
        showAccessibilityAlert()
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "InfiniWake: нужен доступ Accessibility"
        alert.informativeText = """
        Чтобы лампа Caps Lock горела без настоящего CAPS-ввода, разреши InfiniWake в \
        Системные настройки → Конфиденциальность и безопасность → Универсальный доступ.

        Keep-awake уже включён; лампа заработает после выдачи доступа (включи режим ещё раз).
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Открыть настройки")
        alert.addButton(withTitle: "Позже")
        if alert.runModal() == .alertFirstButtonReturn {
            capsFilter.openAccessibilitySettings()
        }
    }

    private func setAutoOffMinutes(_ minutes: Int) {
        settings.autoOffMinutes = minutes
        settings.save()
        if isEnabled {
            restartDeadline()
        }
        refreshUI()
    }

    private func restartDeadline() {
        if settings.autoOffMinutes > 0 {
            deadline = Date().addingTimeInterval(TimeInterval(settings.autoOffMinutes * 60))
        } else {
            deadline = nil
        }
    }

    private func startTicker() {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.onTick()
        }
    }

    private func onTick() {
        guard isEnabled else { return }
        if let deadline, Date() >= deadline {
            disable()
            // После таймера — явный sleep, как в Capsomnia
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            process.arguments = ["sleepnow"]
            try? process.run()
            return
        }
        refreshUI()
    }

    /// Caps Lock — только лампа. Без Accessibility лампу не трогаем (иначе будет CAPS).
    /// Если пользователь нажал Caps Lock (смена языка) и LED погас — снова зажигаем.
    private func syncCapsLockLED() {
        guard settings.useCapsLockLED, isEnabled else { return }
        guard capsFilter.isTrusted, capsFilter.ensureTapInstalled() else { return }
        capsFilter.setFilteringEnabled(true)
        if !capsLED.isOn() {
            _ = capsLED.setOn(true)
        }
    }

    private func refreshUI() {
        let remaining: String
        if !isEnabled {
            remaining = settings.autoOffMinutes == 0 ? "∞" : formatRemaining(TimeInterval(settings.autoOffMinutes * 60))
        } else if let deadline {
            remaining = formatRemaining(deadline.timeIntervalSinceNow)
        } else {
            remaining = "∞"
        }

        statusItem.update(
            enabled: isEnabled,
            remainingText: remaining,
            autoOffMinutes: settings.autoOffMinutes,
            hotkeyTitle: HotKeyManager.displayName(
                keyCode: settings.hotkeyKeyCode,
                modifiers: settings.hotkeyModifiers
            ),
            helperOK: sleepGuard.hasPrivilegedHelper
        )
    }

    private func formatRemaining(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d", hours, minutes)
        }
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        }
        return "\(seconds)с"
    }

    private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(
                settings: settings,
                onSave: { [weak self] updated in
                    self?.applySettings(updated)
                }
            )
        } else {
            settingsWindow?.updateSettings(settings)
        }
        settingsWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func applyLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if settings.launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Игнорируем: в dev-сборке без установленного .app регистрация может не пройти
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
