import Foundation

/// Represents the duration options in the Control Center popover:
/// `∞` · `15m` `30m` `45m` · `1h` `4h` `8h` `12h`
public enum DurationPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case indefinite = "indefinite"
    case mins15 = "mins15"
    case mins30 = "mins30"
    case mins45 = "mins45"
    case hours1 = "hours1"
    case hours4 = "hours4"
    case hours8 = "hours8"
    case hours12 = "hours12"

    public var id: String { rawValue }

    public enum Group: Sendable, Equatable {
        case indefinite
        case minutes
        case hours
    }

    public var group: Group {
        switch self {
        case .indefinite:
            return .indefinite
        case .mins15, .mins30, .mins45:
            return .minutes
        case .hours1, .hours4, .hours8, .hours12:
            return .hours
        }
    }

    /// Duration in seconds, or `nil` for `.indefinite`.
    public var durationSeconds: TimeInterval? {
        switch self {
        case .indefinite:
            return nil
        case .mins15:
            return 15 * 60
        case .mins30:
            return 30 * 60
        case .mins45:
            return 45 * 60
        case .hours1:
            return 1 * 3600
        case .hours4:
            return 4 * 3600
        case .hours8:
            return 8 * 3600
        case .hours12:
            return 12 * 3600
        }
    }

    /// Primary label inside the circular button.
    public var primaryLabel: String {
        switch self {
        case .indefinite:
            return "∞"
        case .mins15:
            return "15"
        case .mins30:
            return "30"
        case .mins45:
            return "45"
        case .hours1:
            return "1"
        case .hours4:
            return "4"
        case .hours8:
            return "8"
        case .hours12:
            return "12"
        }
    }

    /// Micro-unit suffix (`m` for minutes, `h` for hours, `nil` for infinity).
    public var unitBadge: String? {
        switch self {
        case .indefinite:
            return nil
        case .mins15, .mins30, .mins45:
            return "m"
        case .hours1, .hours4, .hours8, .hours12:
            return "h"
        }
    }

    /// Accessible full description for VoiceOver and tooltips.
    public var accessibilityTitle: String {
        switch self {
        case .indefinite:
            return "Indefinitely"
        case .mins15:
            return "15 Minutes"
        case .mins30:
            return "30 Minutes"
        case .mins45:
            return "45 Minutes"
        case .hours1:
            return "1 Hour"
        case .hours4:
            return "4 Hours"
        case .hours8:
            return "8 Hours"
        case .hours12:
            return "12 Hours"
        }
    }

    public static let minutePresets: [DurationPreset] = [.mins15, .mins30, .mins45]
    public static let hourPresets: [DurationPreset] = [.hours1, .hours4, .hours8, .hours12]
}
