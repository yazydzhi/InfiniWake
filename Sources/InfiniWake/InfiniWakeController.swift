import AppKit
import Carbon
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
    private var inputSourceObserver: NSObjectProtocol?
    /// После смены раскладки Caps Lock гасится — recovery с задержками.
    private var inputSourceRecoveryWorkItem: DispatchWorkItem?
    private var lastCapsLockKeyReassertAt: Date = .distantPast
    /// В поле пароля (Secure Event Input) временно гасим Caps Lock — иначе ввод «в капсе».
    private var secureInputOverrideActive = false
    private var nextSecureInputRetryAt = Date.distantPast
    private lazy var secureInputFocusMonitor = SecureInputFocusMonitor { [weak self] in
        self?.syncSecureInputCapsLockOverride(reason: "focus")
    }

    init() {
        settings = InfiniWakeSettings.load()
        applyLanguage()
    }

    /// Режим держит soft Caps Lock ON (LED и/или хоткей Caps Lock).
    private var holdsCapsLockForMode: Bool {
        isEnabled && (settings.useCapsLockLED || hotKey.usesCapsLock)
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
        hotKey.onCapsLockFollow = { [weak self] on in
            guard let self, !self.secureInputOverrideActive else { return }
            if on {
                self.enable()
            } else {
                self.disable()
            }
        }
        hotKey.register(keyCode: settings.hotkeyKeyCode, modifiers: settings.hotkeyModifiers)

        // Иначе сторонний драйвер клавиатуры может держать физическую лампу Off при soft Caps ON
        _ = CapsLockLEDDriverFix.ensureBuiltInKeyboardLEDPassthrough()

        capsFilter.onCapsLockKey = { [weak self] in
            // Если Caps Lock — хоткей, состояние ведёт HotKeyManager; тут только LED recovery
            guard let self, !self.hotKey.usesCapsLock, !self.secureInputOverrideActive else { return }
            self.scheduleInputSourceLEDRecovery(reason: "capsLockKey")
        }
        installWakeObservers()
        installInputSourceObserver()

        applyLaunchAtLogin()
        statusItem.setVisible(settings.showMenuBarIcon)
        refreshUI()

        // Опрос LED / Secure Input ~150 ms
        let ledTimer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.syncCapsLockLED()
        }
        RunLoop.main.add(ledTimer, forMode: .common)
        ledSyncTimer = ledTimer
    }

    func shutdown() {
        endKeepAliveActivity()
        removeWakeObservers()
        removeInputSourceObserver()
        inputSourceRecoveryWorkItem?.cancel()
        tickTimer?.invalidate()
        ledSyncTimer?.invalidate()
        accessibilityRetryTimer?.invalidate()
        clearSecureInputOverride(restoreCapsLock: false)
        secureInputFocusMonitor.stop()
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
        secureInputFocusMonitor.start()
        syncSecureInputCapsLockOverride(reason: "enable")
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
        clearSecureInputOverride(restoreCapsLock: false)
        secureInputFocusMonitor.stop()
        applyCapsLockIndicator(active: false)
        refreshUI()
    }

    func applySettings(_ newSettings: InfiniWakeSettings) {
        let languageChanged = newSettings.language != settings.language
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
        // Окно настроек не закрываем: изменения применяются сразу; при смене языка обновляем подписи
        if languageChanged {
            settingsWindow?.refreshAfterLanguageChange(settings)
        }
        refreshUI()
    }

    private func applyLanguage() {
        L10n.language = AppLanguage.resolved(from: settings.language)
    }

    /// LED + фильтр alphaShift; Caps Lock flagsChanged не глотаем — иначе лампа часто гаснет.
    private func applyCapsLockIndicator(active: Bool) {
        guard active, settings.useCapsLockLED else {
            accessibilityRetryTimer?.invalidate()
            accessibilityRetryTimer = nil
            capsFilter.setFilteringEnabled(false)
            _ = capsLED.setOn(false)
            return
        }

        reassertCapsLockLED(reason: "enable")

        // Не вызываем системный prompt на каждый toggle — из‑за этого был цикл запросов.
        if tryActivateCapsLockFilter() {
            return
        }

        // Keep-awake + LED остаются; без фильтра система может гасить лампу — ретраим Accessibility.
        startAccessibilityRetryLoop()
        if !didShowAccessibilityAlertThisSession {
            didShowAccessibilityAlertThisSession = true
            showAccessibilityAlert()
        }
    }

    /// Ставит CGEvent-фильтр. true = tap готов. LED зажигается отдельно.
    @discardableResult
    private func tryActivateCapsLockFilter() -> Bool {
        _ = capsLED.forceOn()
        guard capsFilter.isTrusted, capsFilter.ensureTapInstalled() else {
            return false
        }
        capsFilter.setFilteringEnabled(true)
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

    /// Caps Lock — лампа + Secure Input override.
    private func syncCapsLockLED() {
        syncSecureInputCapsLockOverride(reason: "sync")
        guard !secureInputOverrideActive else { return }
        reassertCapsLockLED(reason: "sync")
    }

    /// В password/secure-полях временно OFF, иначе ввод как с Caps Lock (tap не видит события).
    private func syncSecureInputCapsLockOverride(reason: String) {
        guard holdsCapsLockForMode else {
            if secureInputOverrideActive {
                clearSecureInputOverride(restoreCapsLock: false)
            }
            return
        }

        let secure = SecureInputStateReader.isSecureEventInputEnabled()
        let now = Date()

        if secure {
            if secureInputOverrideActive {
                // Держим OFF, если кто-то снова зажёг Caps Lock
                if capsLED.isOn(), now >= nextSecureInputRetryAt {
                    _ = capsLED.setOn(false, verify: false)
                    hotKey.noteExternalCapsLockState(false)
                    nextSecureInputRetryAt = now.addingTimeInterval(0.2)
                }
                return
            }
            guard now >= nextSecureInputRetryAt else { return }
            inputSourceRecoveryWorkItem?.cancel()
            let ok = capsLED.setOn(false, verify: false)
            if ok || !capsLED.isOn() {
                secureInputOverrideActive = true
                hotKey.noteExternalCapsLockState(false)
                nextSecureInputRetryAt = .distantPast
            } else {
                nextSecureInputRetryAt = now.addingTimeInterval(0.35)
            }
            return
        }

        // Secure Input закончился — вернуть Caps Lock, если режим ещё on
        guard secureInputOverrideActive else { return }
        guard now >= nextSecureInputRetryAt else { return }
        let ok = capsLED.setOn(true, verify: false)
        if ok || capsLED.isOn() {
            secureInputOverrideActive = false
            hotKey.noteExternalCapsLockState(true)
            nextSecureInputRetryAt = .distantPast
            if settings.useCapsLockLED {
                reassertCapsLockLED(reason: "secureRestore")
            }
        } else {
            nextSecureInputRetryAt = now.addingTimeInterval(0.35)
        }
    }

    private func clearSecureInputOverride(restoreCapsLock: Bool) {
        guard secureInputOverrideActive || restoreCapsLock else {
            secureInputOverrideActive = false
            return
        }
        secureInputOverrideActive = false
        nextSecureInputRetryAt = .distantPast
        if restoreCapsLock, holdsCapsLockForMode {
            _ = capsLED.setOn(true, verify: false)
            hotKey.noteExternalCapsLockState(true)
        }
    }

    /// После смены раскладки (Caps Lock = язык) macOS гасит lock — recovery.
    private func scheduleInputSourceLEDRecovery(reason: String) {
        guard settings.useCapsLockLED, isEnabled, !secureInputOverrideActive else { return }
        if reason == "capsLockKey" {
            let now = Date()
            guard now.timeIntervalSince(lastCapsLockKeyReassertAt) > 0.2 else { return }
            lastCapsLockKeyReassertAt = now
        }

        inputSourceRecoveryWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isEnabled, !self.secureInputOverrideActive else { return }
            self.reassertCapsLockLED(reason: "inputSource")
            // Повтор: система иногда гасит LED с задержкой после TIS notify
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                guard let self, !self.secureInputOverrideActive else { return }
                self.reassertCapsLockLED(reason: "inputSource")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self, !self.secureInputOverrideActive else { return }
                self.reassertCapsLockLED(reason: "inputSource")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
                guard let self, !self.secureInputOverrideActive else { return }
                self.reassertCapsLockLED(reason: "inputSource")
            }
        }
        inputSourceRecoveryWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    /// Перезажигает LED. Не зависит от Accessibility.
    private func reassertCapsLockLED(reason: String) {
        guard settings.useCapsLockLED, isEnabled, !secureInputOverrideActive else { return }
        if capsFilter.isTrusted {
            _ = capsFilter.ensureTapInstalled()
            capsFilter.setFilteringEnabled(true)
        }

        if reason == "enable" {
            _ = capsLED.forceOn()
            return
        }

        // Смена языка / wake / Caps Lock — всегда пишем on (система только что погасила)
        if reason == "inputSource"
            || reason == "capsLockKey"
            || reason == "wake"
            || reason == "secureRestore"
            || reason.hasPrefix("afterDisplay") {
            _ = capsLED.setOn(true, verify: false)
            return
        }

        // sync/tick: только если погасла
        if !capsLED.isOn() {
            _ = capsLED.setOn(true, verify: false)
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

    private func installInputSourceObserver() {
        removeInputSourceObserver()
        let name = Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)
        inputSourceObserver = DistributedNotificationCenter.default().addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleInputSourceLEDRecovery(reason: "inputSource")
        }
    }

    private func removeInputSourceObserver() {
        if let inputSourceObserver {
            DistributedNotificationCenter.default().removeObserver(inputSourceObserver)
            self.inputSourceObserver = nil
        }
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
            helperOK: sleepGuard.hasPrivilegedHelper,
            iconStyle: settings.menuBarIconStyle
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
