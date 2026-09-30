import Foundation
import Combine
import AppKit
import SwiftUI

/// Central observable state store for **I'll Be Back**.
@MainActor
public final class AppStore: ObservableObject {
    // MARK: - Active Session State
    @Published public private(set) var isActive: Bool = false
    @Published public private(set) var startedAt: Date? = nil
    @Published public private(set) var expiresAt: Date? = nil
    @Published public private(set) var remainingSeconds: TimeInterval? = nil

    // MARK: - Popover UI Expansion & Interaction State
    @Published public var isDurationExpanded: Bool = true
    @Published public var isSettingsExpanded: Bool = false
    @Published public var showingAbout: Bool = false
    @Published public var isRecordingShortcut: Bool = false
    @Published public var hoveredElementID: String? = nil

    // MARK: - Persisted Settings
    @Published public var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            settings.save(to: userDefaults)
            onStateChanged?()
        }
    }

    // MARK: - Services
    public let sleepService: SleepAssertionService
    public let powerService: PowerMonitorService
    public let shortcutService: GlobalShortcutService
    public let loginService: LaunchAtLoginService
    public let notificationService: NotificationService

    private let userDefaults: UserDefaults
    nonisolated(unsafe) private var timerTask: Task<Void, Never>?
    nonisolated(unsafe) private var localKeyMonitor: Any?
    nonisolated(unsafe) private var wakeObserver: NSObjectProtocol?

    /// Callback invoked whenever `isActive` or `settings.coloredMenuBarIcon` changes so `StatusBarController` can refresh the menu bar icon.
    public var onStateChanged: (() -> Void)?

    public init(userDefaults: UserDefaults = .standard, startServices: Bool = true) {
        self.userDefaults = userDefaults
        var loadedSettings = AppSettings.load(from: userDefaults)
        let loginSvc = LaunchAtLoginService()
        if startServices {
            loadedSettings.launchAtLogin = loginSvc.isEnabled
        }
        self.settings = loadedSettings
        self.sleepService = SleepAssertionService()
        self.powerService = PowerMonitorService()
        self.shortcutService = GlobalShortcutService()
        self.loginService = loginSvc
        self.notificationService = NotificationService()

        guard startServices else { return }

        setupCallbacks()

        if settings.globalShortcutEnabled {
            shortcutService.register(config: settings.shortcutConfig)
        }

        powerService.startMonitoring()

        if settings.activateAtLaunch {
            activate(duration: settings.selectedDuration)
        }
    }

    deinit {
        timerTask?.cancel()
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    private func setupCallbacks() {
        shortcutService.onShortcutTriggered = { [weak self] in
            guard let self else { return }
            self.toggleActive()
        }

        powerService.onPowerChange = { [weak self] oldSnap, newSnap in
            guard let self else { return }
            self.handlePowerTransition(from: oldSnap, to: newSnap)
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.tickCountdown()
            }
        }
    }

    // MARK: - Activation & Timer Control

    public func toggleActive() {
        if isActive {
            deactivate()
        } else {
            activate(duration: settings.selectedDuration)
        }
    }

    public func selectDuration(_ preset: DurationPreset) {
        activate(duration: preset)
    }

    public func activate(duration: DurationPreset? = nil) {
        let targetDuration = duration ?? settings.selectedDuration
        settings.selectedDuration = targetDuration

        let acquired = sleepService.acquireAssertion(
            allowDisplaySleep: settings.allowDisplayToSleep,
            reason: "I'll Be Back — Active (\(targetDuration.accessibilityTitle))"
        )

        guard acquired else { return }

        let now = Date()
        isActive = true
        startedAt = now

        if let seconds = targetDuration.durationSeconds {
            expiresAt = now.addingTimeInterval(seconds)
            remainingSeconds = seconds
            if settings.allowNotifications {
                notificationService.requestAuthorizationIfNeeded()
            }
            startCountdownLoop()
        } else {
            expiresAt = nil
            remainingSeconds = nil
            stopCountdownLoop()
        }

        onStateChanged?()
    }

    public func deactivate() {
        stopCountdownLoop()
        sleepService.releaseAssertion()
        isActive = false
        startedAt = nil
        expiresAt = nil
        remainingSeconds = nil
        onStateChanged?()
    }

    private func startCountdownLoop() {
        stopCountdownLoop()
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { break }
                self.tickCountdown()
            }
        }
    }

    private func stopCountdownLoop() {
        timerTask?.cancel()
        timerTask = nil
    }

    public func tickCountdown(now: Date = Date()) {
        guard isActive, let expiresAt else { return }
        let remaining = expiresAt.timeIntervalSince(now)
        if remaining <= 0 {
            let finishedLabel = settings.selectedDuration.accessibilityTitle
            deactivate()
            if settings.allowNotifications {
                notificationService.sendSessionFinishedNotification(durationLabel: finishedLabel)
            }
        } else {
            remainingSeconds = remaining
        }
    }

    // MARK: - Settings Toggles

    public func toggleLaunchAtLogin() {
        let newValue = !settings.launchAtLogin
        if loginService.setEnabled(newValue) {
            settings.launchAtLogin = newValue
        } else {
            settings.launchAtLogin = loginService.isEnabled
        }
    }

    public func toggleActivateAtLaunch() {
        settings.activateAtLaunch.toggle()
    }

    public func toggleActivateWithLeftClick() {
        settings.activateWithLeftClick.toggle()
    }

    public func toggleGlobalShortcut() {
        settings.globalShortcutEnabled.toggle()
        if settings.globalShortcutEnabled {
            shortcutService.register(config: settings.shortcutConfig)
        } else {
            stopRecordingShortcut()
            shortcutService.unregister()
        }
    }

    public func toggleRecordingShortcut() {
        if isRecordingShortcut {
            stopRecordingShortcut()
        } else {
            startRecordingShortcut()
        }
    }

    public func startRecordingShortcut() {
        stopRecordingShortcut()
        isRecordingShortcut = true
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { // Escape cancels recording
                self.stopRecordingShortcut()
                return nil
            }
            if let newShortcut = GlobalShortcutService.shortcutConfig(from: event) {
                self.updateShortcut(newShortcut)
                return nil
            }
            return event
        }
    }

    public func stopRecordingShortcut() {
        isRecordingShortcut = false
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }

    public func updateShortcut(_ newConfig: KeyboardShortcutConfig) {
        stopRecordingShortcut()
        settings.shortcutConfig = newConfig
        if settings.globalShortcutEnabled {
            shortcutService.register(config: newConfig)
        }
    }

    public func toggleAllowDisplayToSleep() {
        settings.allowDisplayToSleep.toggle()
        if isActive {
            sleepService.acquireAssertion(
                allowDisplaySleep: settings.allowDisplayToSleep,
                reason: "I'll Be Back — Active (\(settings.selectedDuration.accessibilityTitle))"
            )
        }
    }

    public func toggleAllowNotifications() {
        settings.allowNotifications.toggle()
        if settings.allowNotifications {
            notificationService.requestAuthorizationIfNeeded()
        }
    }

    public func toggleColoredMenuBarIcon() {
        settings.coloredMenuBarIcon.toggle()
    }

    public func toggleActivateOnPowerConnect() {
        settings.activateOnPowerConnect.toggle()
    }

    public func toggleDeactivateOnPowerDisconnect() {
        settings.deactivateOnPowerDisconnect.toggle()
    }

    public func togglePauseOnLowBattery() {
        settings.pauseOnLowBattery.toggle()
    }

    // MARK: - Power Transitions

    public func handlePowerTransition(from oldSnap: PowerStatusSnapshot, to newSnap: PowerStatusSnapshot) {
        if !oldSnap.isConnectedToAC && newSnap.isConnectedToAC {
            if settings.activateOnPowerConnect && !isActive {
                activate(duration: settings.selectedDuration)
            }
        }

        if oldSnap.isConnectedToAC && !newSnap.isConnectedToAC {
            if settings.deactivateOnPowerDisconnect && isActive {
                deactivate()
                return
            }
        }

        if !newSnap.isConnectedToAC,
           settings.pauseOnLowBattery,
           isActive,
           let percent = newSnap.batteryPercentage,
           percent <= settings.lowBatteryThreshold {
            deactivate()
            if settings.allowNotifications {
                notificationService.sendLowBatteryPausedNotification(batteryPercent: percent)
            }
        }
    }

    // MARK: - Formatted Display Strings & Progress

    private static let endTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    /// Subtitle displayed directly under "I'll Be Back" when active (e.g. "Active Until 8:45 AM" or "Active Indefinitely").
    public var statusSubtitle: String? {
        guard isActive else { return nil }
        if let expiresAt, let remainingSeconds {
            let timeStr = Self.endTimeFormatter.string(from: expiresAt)
            let remStr = Self.formatRemainingShort(remainingSeconds)
            return "Active Until \(timeStr) · \(remStr)"
        }
        return "Active Indefinitely"
    }

    /// Progress fraction (`0.0 ... 1.0`) for timed durations, or `nil` for indefinite/inactive.
    public var timerProgress: Double? {
        guard isActive,
              let total = settings.selectedDuration.durationSeconds,
              total > 0,
              let remaining = remainingSeconds else {
            return nil
        }
        return min(max(remaining / total, 0.0), 1.0)
    }

    /// Active UI accent color: Terminator Cyber-Red when `coloredMenuBarIcon` is ON, or native macOS System Blue when OFF.
    public var accentColor: Color {
        if settings.coloredMenuBarIcon {
            return Color(red: 1.0, green: 0.231, blue: 0.188) // Cyber-Red #FF3B30
        }
        return Color(red: 0.0, green: 0.478, blue: 1.0) // System Blue #007AFF
    }

    public static func formatRemainingShort(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(Int(seconds.rounded()), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m left" : "\(hours)h left"
        } else if minutes > 0 {
            return "\(minutes)m left"
        } else {
            return "\(secs)s left"
        }
    }

    // MARK: - Open Source Repository Link

    public static let githubRepoURL = URL(string: "https://github.com/Alex777x/IllBeBack")!

    public func openGitHubRepo() {
        NSWorkspace.shared.open(Self.githubRepoURL)
    }
}
