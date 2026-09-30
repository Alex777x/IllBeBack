import Foundation
import Carbon.HIToolbox

/// Represents a customizable global keyboard shortcut (default: ⌃⌘I).
public struct KeyboardShortcutConfig: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var carbonModifiers: UInt32
    public var keyDisplay: String

    public static let defaultShortcut = KeyboardShortcutConfig(
        keyCode: UInt32(kVK_ANSI_I),
        carbonModifiers: UInt32(controlKey | cmdKey),
        keyDisplay: "I"
    )

    public init(keyCode: UInt32, carbonModifiers: UInt32, keyDisplay: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.keyDisplay = keyDisplay
    }

    /// Formatted string such as "⌃⌘I".
    public var displayString: String {
        var result = ""
        if (carbonModifiers & UInt32(controlKey)) != 0 { result += "⌃" }
        if (carbonModifiers & UInt32(optionKey)) != 0 { result += "⌥" }
        if (carbonModifiers & UInt32(shiftKey)) != 0 { result += "⇧" }
        if (carbonModifiers & UInt32(cmdKey)) != 0 { result += "⌘" }
        result += keyDisplay.uppercased()
        return result
    }
}

/// Persistent user preferences for I'll Be Back.
public struct AppSettings: Codable, Equatable, Sendable {
    public var launchAtLogin: Bool
    public var activateAtLaunch: Bool
    public var activateWithLeftClick: Bool
    public var globalShortcutEnabled: Bool
    public var allowDisplayToSleep: Bool
    public var allowNotifications: Bool
    public var coloredMenuBarIcon: Bool
    public var activateOnPowerConnect: Bool
    public var deactivateOnPowerDisconnect: Bool
    public var pauseOnLowBattery: Bool
    public var lowBatteryThreshold: Int
    public var selectedDuration: DurationPreset
    public var shortcutConfig: KeyboardShortcutConfig

    private static let storageKey = "com.illbeback.app.settings.v1"

    public init(
        launchAtLogin: Bool = false,
        activateAtLaunch: Bool = false,
        activateWithLeftClick: Bool = false,
        globalShortcutEnabled: Bool = false,
        allowDisplayToSleep: Bool = false,
        allowNotifications: Bool = true,
        coloredMenuBarIcon: Bool = true,
        activateOnPowerConnect: Bool = false,
        deactivateOnPowerDisconnect: Bool = false,
        pauseOnLowBattery: Bool = true,
        lowBatteryThreshold: Int = 20,
        selectedDuration: DurationPreset = .indefinite,
        shortcutConfig: KeyboardShortcutConfig = .defaultShortcut
    ) {
        self.launchAtLogin = launchAtLogin
        self.activateAtLaunch = activateAtLaunch
        self.activateWithLeftClick = activateWithLeftClick
        self.globalShortcutEnabled = globalShortcutEnabled
        self.allowDisplayToSleep = allowDisplayToSleep
        self.allowNotifications = allowNotifications
        self.coloredMenuBarIcon = coloredMenuBarIcon
        self.activateOnPowerConnect = activateOnPowerConnect
        self.deactivateOnPowerDisconnect = deactivateOnPowerDisconnect
        self.pauseOnLowBattery = pauseOnLowBattery
        self.lowBatteryThreshold = lowBatteryThreshold
        self.selectedDuration = selectedDuration
        self.shortcutConfig = shortcutConfig
    }

    public static func load(from defaults: UserDefaults = .standard) -> AppSettings {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return decoded
    }

    public func save(to defaults: UserDefaults = .standard) {
        if let encoded = try? JSONEncoder().encode(self) {
            defaults.set(encoded, forKey: Self.storageKey)
        }
    }
}
