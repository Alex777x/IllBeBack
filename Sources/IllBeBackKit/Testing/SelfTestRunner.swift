import Foundation
import AppKit
import SwiftUI

/// Automated self-test and UI snapshot renderer for **I'll Be Back**.
@MainActor
public enum SelfTestRunner {

    public static func runAllTests() -> Bool {
        print("🤖 Running I'll Be Back Self-Test Suite...")
        var passedCount = 0
        var failedCount = 0

        func check(_ name: String, _ condition: Bool) {
            if condition {
                print("  ✅ PASS: \(name)")
                passedCount += 1
            } else {
                print("  ❌ FAIL: \(name)")
                failedCount += 1
            }
        }

        // 1. DurationPreset validation
        check("DurationPreset has 8 presets", DurationPreset.allCases.count == 8)
        check("Indefinite preset has nil seconds", DurationPreset.indefinite.durationSeconds == nil)
        check("15m preset equals 900s", DurationPreset.mins15.durationSeconds == 900)
        check("12h preset equals 43200s", DurationPreset.hours12.durationSeconds == 43200)
        check("Minute presets have 'm' unit badge", DurationPreset.mins30.unitBadge == "m")
        check("Hour presets have 'h' unit badge", DurationPreset.hours4.unitBadge == "h")

        // 2. Real IOKit SleepAssertionService acquisition & release
        let sleepService = SleepAssertionService()
        let acquiredDisplay = sleepService.acquireAssertion(allowDisplaySleep: false, reason: "IllBeBack Self-Test Display")
        check("Acquire PreventUserIdleDisplaySleep assertion", acquiredDisplay && sleepService.isHoldingAssertion && sleepService.activeAssertionID != 0)

        let acquiredSystem = sleepService.acquireAssertion(allowDisplaySleep: true, reason: "IllBeBack Self-Test System")
        check("Switch to PreventUserIdleSystemSleep assertion", acquiredSystem && sleepService.isHoldingAssertion && sleepService.currentAllowDisplaySleep == true)

        sleepService.releaseAssertion()
        check("Release IOKit sleep assertion cleanly", !sleepService.isHoldingAssertion && sleepService.activeAssertionID == 0)

        // 3. PowerMonitorService snapshot reading
        let powerSnap = PowerMonitorService.readCurrentPowerStatus()
        if let pct = powerSnap.batteryPercentage {
            check("PowerMonitorService reads valid battery percentage (\(pct)%)", (0...100).contains(pct))
        } else {
            check("PowerMonitorService reads valid AC status on desktop Mac", powerSnap.isConnectedToAC)
        }

        // 4. AppStore state & power transitions
        let suiteName = "com.illbeback.selftest.\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suiteName)!
        let store = AppStore(userDefaults: testDefaults, startServices: false)

        check("Initial store is inactive", !store.isActive)
        check("Default coloredMenuBarIcon is true (red eye dot enabled)", store.settings.coloredMenuBarIcon == true)

        store.selectDuration(.mins15)
        check("Selecting 15m preset activates store and sets countdown", store.isActive && store.remainingSeconds != nil && store.sleepService.isHoldingAssertion)
        check("Status subtitle contains Active Until", store.statusSubtitle?.contains("Active Until") == true)
        check("Timer progress is ~1.0 on start", (store.timerProgress ?? 0) > 0.99)

        // Test power connect/disconnect & low battery auto-pause
        store.deactivate()
        store.settings.activateOnPowerConnect = true
        store.settings.deactivateOnPowerDisconnect = true
        store.settings.pauseOnLowBattery = true

        let batterySnap = PowerStatusSnapshot(isConnectedToAC: false, batteryPercentage: 80, isCharging: false)
        let acSnap = PowerStatusSnapshot(isConnectedToAC: true, batteryPercentage: 80, isCharging: true)
        store.handlePowerTransition(from: batterySnap, to: acSnap)
        check("Auto-activates on AC power connect", store.isActive)

        store.handlePowerTransition(from: acSnap, to: batterySnap)
        check("Auto-deactivates on AC power disconnect", !store.isActive)

        store.activate(duration: .hours1)
        let lowBatterySnap = PowerStatusSnapshot(isConnectedToAC: false, batteryPercentage: 15, isCharging: false)
        store.handlePowerTransition(from: batterySnap, to: lowBatterySnap)
        check("Auto-pauses when battery drops below 20%", !store.isActive)

        // Test countdown expiration deactivation
        store.activate(duration: .mins15)
        let futureDate = Date().addingTimeInterval(20 * 60)
        store.tickCountdown(now: futureDate)
        check("Timer expiration automatically deactivates session and releases IOKit assertion", !store.isActive && !store.sleepService.isHoldingAssertion)

        // 5. CyberVisorIcon rendering across all 3 modes
        let inactiveImg = CyberVisorIcon.makeMenuBarImage(isActive: false, isColored: false)
        let activeMonoImg = CyberVisorIcon.makeMenuBarImage(isActive: true, isColored: false)
        let activeColorImg = CyberVisorIcon.makeMenuBarImage(isActive: true, isColored: true)
        check("CyberVisorIcon renders valid images and template flags",
              inactiveImg.isTemplate && activeMonoImg.isTemplate && !activeColorImg.isTemplate)

        testDefaults.removePersistentDomain(forName: suiteName)

        print("🏁 Self-Test Summary: \(passedCount) passed, \(failedCount) failed.")
        return failedCount == 0
    }

    public static func renderSnapshots(to directoryPath: String) throws {
        let dirURL = URL(fileURLWithPath: directoryPath, isDirectory: true)
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let suiteName = "com.illbeback.snapshots.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // 1. Light Mode — Active Indefinite + Duration Expanded
        do {
            let store = AppStore(userDefaults: defaults, startServices: false)
            store.isDurationExpanded = true
            store.isSettingsExpanded = false
            store.settings.coloredMenuBarIcon = false
            store.activate(duration: .indefinite)
            let view = PopoverPreviewWrapper(store: store, isDark: false)
            try saveSnapshot(of: view, to: dirURL.appendingPathComponent("popover_light_duration.png"))
            store.deactivate()
        }

        // 2. Dark Mode — Active 15m Timer + Duration Expanded
        do {
            let store = AppStore(userDefaults: defaults, startServices: false)
            store.isDurationExpanded = true
            store.isSettingsExpanded = false
            store.settings.coloredMenuBarIcon = false
            store.selectDuration(.mins15)
            let view = PopoverPreviewWrapper(store: store, isDark: true)
            try saveSnapshot(of: view, to: dirURL.appendingPathComponent("popover_dark_timer.png"))
            store.deactivate()
        }

        // 3. Dark Mode — Settings Expanded + Colored Cyber-Red Mode with Red Eye Dot in Glasses
        do {
            let store = AppStore(userDefaults: defaults, startServices: false)
            store.isDurationExpanded = false
            store.isSettingsExpanded = true
            store.settings.launchAtLogin = true
            store.settings.activateAtLaunch = true
            store.settings.globalShortcutEnabled = true
            store.settings.allowNotifications = true
            store.settings.coloredMenuBarIcon = true
            store.settings.pauseOnLowBattery = true
            store.selectDuration(.hours1)
            let view = PopoverPreviewWrapper(store: store, isDark: true)
            try saveSnapshot(of: view, to: dirURL.appendingPathComponent("popover_dark_settings_cyber.png"))
            store.deactivate()
        }
    }

    private static func saveSnapshot<V: View>(of view: V, to url: URL) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        guard let cgImage = renderer.cgImage else {
            throw NSError(domain: "SelfTestRunner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to render CGImage"])
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "SelfTestRunner", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
        }
        try pngData.write(to: url)
    }
}

private struct PopoverPreviewWrapper: View {
    let store: AppStore
    let isDark: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: isDark
                    ? [Color(red: 0.06, green: 0.10, blue: 0.28), Color(red: 0.03, green: 0.05, blue: 0.16)]
                    : [Color(red: 0.72, green: 0.84, blue: 0.98), Color(red: 0.45, green: 0.66, blue: 0.94)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 10) {
                HStack(spacing: 14) {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(nsImage: CyberVisorIcon.makeMenuBarImage(
                            isActive: store.isActive,
                            isColored: store.settings.coloredMenuBarIcon
                        ))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(isDark ? Color.white.opacity(0.16) : Color.black.opacity(0.10))
                    )

                    Image(systemName: "wifi")
                    Image(systemName: "magnifyingglass")
                    Image(systemName: "switch.2")
                    Text("Tue Sep 29  9:41 AM")
                        .font(.system(size: 12, weight: .medium))
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isDark ? .white : .black.opacity(0.85))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(isDark ? Color.black.opacity(0.35) : Color.white.opacity(0.45))

                PopoverContentView(store: store, onQuit: {})
                    .background(
                        isDark
                            ? Color(red: 0.11, green: 0.12, blue: 0.20).opacity(0.92)
                            : Color(red: 0.93, green: 0.96, blue: 0.99).opacity(0.92)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                isDark ? Color.white.opacity(0.16) : Color.black.opacity(0.10),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.28), radius: 18, y: 8)
                    .padding(.bottom, 20)
            }
        }
        .frame(width: 360)
        .environment(\.colorScheme, isDark ? .dark : .light)
    }
}
