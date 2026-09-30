import Foundation
import UserNotifications

/// Sends local user notifications when a timed stay-awake session completes or is paused by low battery.
@MainActor
public final class NotificationService {
    public init() {}

    private var hasValidAppBundle: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundlePath.hasSuffix(".app")
    }

    public func requestAuthorizationIfNeeded() {
        guard hasValidAppBundle else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    public func sendSessionFinishedNotification(durationLabel: String) {
        guard hasValidAppBundle else { return }
        let content = UNMutableNotificationContent()
        content.title = "I'll Be Back"
        content.body = "Stay-awake timer (\(durationLabel)) finished. Your Mac can sleep normally now."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "com.illbeback.session.finished.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    public func sendLowBatteryPausedNotification(batteryPercent: Int) {
        guard hasValidAppBundle else { return }
        let content = UNMutableNotificationContent()
        content.title = "I'll Be Back — Paused for Battery Saver"
        content.body = "Battery dropped to \(batteryPercent)%. Stay-awake was automatically paused to protect your Mac."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "com.illbeback.session.lowbattery.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
