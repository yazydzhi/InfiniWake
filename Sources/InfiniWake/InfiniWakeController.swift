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
    /// Держит процесс «живым», иначе App Nap глушит таймер LED.
    private var keepAliveActivity: NSObjectProtocol?
    private var wakeObservers: [NSObjectProtocol] = []

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

        capsFilter.onCapsLockKey = { [weak self] in
            self?.reassertCapsLockLED(reason: "capsLockKey")
        }
        installWakeObservers()

        applyLaunchAtLogin()
        statusItem.setVisible(settings.showMenuBarIcon)
        refreshUI()

        // common modes — таймер не молчит во время меню / tracking
        let ledTimer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.syncCapsLockLED()
        }
        RunLoop.main.add(ledTimer, forMode: .common)
        ledSyncTimer = ledTimer
    }

    func shutdown() {
        endKeepAliveActivity()
        removeWakeObservers()
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
        beginKeepAliveActivity()
        restartDeadline()
        applyCapsLockIndicator(active: true)
        // При закрытой крышке можно гасить дисплей — работа продолжается.
        // После displaysleep LED часто гаснет с подсветкой клавиатуры — перезажигаем с задержкой.
        if sleepGuard.activeMode == .pmset {
            sleepGuard.sleepDisplayIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.reassertCapsLockLED(reason: "afterDisplaySleep")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.reassertCapsLockLED(reason: "afterDisplaySleepRetry")
            }
        }
        startTicker()
        refreshUI()
    }

    func disable() {
        guard isEnabled else { return }
        isEnabled = false
        deadline = nil
        endKeepAliveActivity()
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
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.onTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    private func onTick() {
        guard isEnabled else { return }
        if let deadline, Date() >= deadline {
            disable()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            process.arguments = ["sleepnow"]
            try? process.run()
            return
        }
        // Дополнительный reassert раз в секунду — страховка от App Nap / сброса HID
        reassertCapsLockLED(reason: "tick")
        refreshUI()
    }

    /// Caps Lock — только лампа. Принудительно держам LED on, пока режим включён.
    private func syncCapsLockLED() {
        reassertCapsLockLED(reason: "sync")
    }

    /// Перезажигает LED. Не смотрим только на isOn(): лампа может быть тухлой при «включённом» state.
    private func reassertCapsLockLED(reason: String) {
        guard settings.useCapsLockLED, isEnabled else { return }
        guard capsFilter.isTrusted, capsFilter.ensureTapInstalled() else { return }
        capsFilter.setFilteringEnabled(true)
        _ = capsLED.setOn(true)
        // На части Mac после Caps Lock / sleep state «догоняет» с задержкой
        if reason == "capsLockKey" || reason == "wake" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self, self.isEnabled else { return }
                _ = self.capsLED.setOn(true)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self, self.isEnabled else { return }
                _ = self.capsLED.setOn(true)
            }
        }
    }

    private func beginKeepAliveActivity() {
        endKeepAliveActivity()
        keepAliveActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .latencyCritical, .idleSystemSleepDisabled],
            reason: "InfiniWake keep-awake and Caps Lock LED sync"
        )
    }

    private func endKeepAliveActivity() {
        if let keepAliveActivity {
            ProcessInfo.processInfo.endActivity(keepAliveActivity)
            self.keepAliveActivity = nil
        }
    }

    private func installWakeObservers() {
        let center = NSWorkspace.shared.notificationCenter
        let names: [NSNotification.Name] = [
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification
        ]
        for name in names {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.reassertCapsLockLED(reason: "wake")
            }
            wakeObservers.append(token)
        }
        // Пробуждение дисплея / смена экранов
        let nc = NotificationCenter.default
        let displayToken = nc.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reassertCapsLockLED(reason: "wake")
        }
        wakeObservers.append(displayToken)
    }

    private func removeWakeObservers() {
        let workspace = NSWorkspace.shared.notificationCenter
        let local = NotificationCenter.default
        for token in wakeObservers {
            workspace.removeObserver(token)
            local.removeObserver(token)
        }
        wakeObservers.removeAll()
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
