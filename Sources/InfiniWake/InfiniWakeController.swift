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
    /// Не спамить диалогом Accessibility при каждом toggle.
    private var didShowAccessibilityAlertThisSession = false
    private var accessibilityRetryTimer: Timer?

    init() {
        settings = InfiniWakeSettings.load()
        applyLanguage()
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
        accessibilityRetryTimer?.invalidate()
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
                title: AppInfo.name,
                message: sleepGuard.lastError ?? L10n.enableFailed
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
        applyLanguage()

        hotKey.register(keyCode: settings.hotkeyKeyCode, modifiers: settings.hotkeyModifiers)
        statusItem.setVisible(settings.showMenuBarIcon)
        applyLaunchAtLogin()

        if wasEnabled {
            restartDeadline()
            applyCapsLockIndicator(active: true)
        } else {
            applyCapsLockIndicator(active: false)
        }
        // Пересоздаём окно настроек, чтобы подтянуть новый язык при следующем открытии
        settingsWindow = nil
        refreshUI()
    }

    private func applyLanguage() {
        L10n.language = AppLanguage.resolved(from: settings.language)
    }

    /// LED + фильтр «не настоящий CAPS». Без Accessibility лампу не зажигаем.
    private func applyCapsLockIndicator(active: Bool) {
        guard active, settings.useCapsLockLED else {
            accessibilityRetryTimer?.invalidate()
            accessibilityRetryTimer = nil
            capsFilter.setFilteringEnabled(false)
            _ = capsLED.setOn(false)
            return
        }

        // Не вызываем системный prompt на каждый toggle — из‑за этого был цикл запросов.
        if tryActivateCapsLockFilter() {
            return
        }

        // Keep-awake остаётся; лампу не жжём без фильтра. Диалог — максимум раз за сессию.
        capsFilter.setFilteringEnabled(false)
        _ = capsLED.setOn(false)
        startAccessibilityRetryLoop()
        if !didShowAccessibilityAlertThisSession {
            didShowAccessibilityAlertThisSession = true
            showAccessibilityAlert()
        }
    }

    /// Пытается поставить CGEvent-фильтр и зажечь LED.
    @discardableResult
    private func tryActivateCapsLockFilter() -> Bool {
        guard capsFilter.isTrusted, capsFilter.ensureTapInstalled() else {
            return false
        }
        capsFilter.setFilteringEnabled(true)
        _ = capsLED.setOn(true)
        accessibilityRetryTimer?.invalidate()
        accessibilityRetryTimer = nil
        return true
    }

    /// После выдачи доступа macOS часто требует перезапуск; пока ждём — тихо ретраим.
    private func startAccessibilityRetryLoop() {
        accessibilityRetryTimer?.invalidate()
        accessibilityRetryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self, self.isEnabled, self.settings.useCapsLockLED else { return }
            if self.tryActivateCapsLockFilter() {
                self.refreshUI()
            }
        }
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = L10n.accessibilityTitle
        alert.informativeText = L10n.accessibilityBody
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.openSettingsButton)
        alert.addButton(withTitle: L10n.quitAndRestartButton)
        alert.addButton(withTitle: L10n.laterButton)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            capsFilter.openAccessibilitySettings()
            // Один системный prompt — только по кнопке, не на каждый toggle
            _ = capsFilter.promptSystemTrustDialogOnce()
        } else if response == .alertSecondButtonReturn {
            NSApp.terminate(nil)
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
            remaining = settings.autoOffMinutes == 0
                ? "∞"
                : L10n.formatRemaining(TimeInterval(settings.autoOffMinutes * 60))
        } else if let deadline {
            remaining = L10n.formatRemaining(deadline.timeIntervalSinceNow)
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
