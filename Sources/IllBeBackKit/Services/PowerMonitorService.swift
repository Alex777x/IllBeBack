import Foundation
import IOKit.ps

/// Snapshot of the Mac's current power source state.
public struct PowerStatusSnapshot: Equatable, Sendable {
    public let isConnectedToAC: Bool
    public let batteryPercentage: Int?
    public let isCharging: Bool

    public init(isConnectedToAC: Bool, batteryPercentage: Int?, isCharging: Bool) {
        self.isConnectedToAC = isConnectedToAC
        self.batteryPercentage = batteryPercentage
        self.isCharging = isCharging
    }
}

/// Monitors macOS power source changes (AC connect/disconnect and battery percentage) via `IOKit.ps`.
@MainActor
public final class PowerMonitorService {
    nonisolated(unsafe) private var runLoopSource: CFRunLoopSource?
    public private(set) var lastSnapshot: PowerStatusSnapshot
    public var onPowerChange: ((PowerStatusSnapshot, PowerStatusSnapshot) -> Void)?

    public init() {
        self.lastSnapshot = Self.readCurrentPowerStatus()
    }

    public func startMonitoring() {
        guard runLoopSource == nil else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ contextPtr in
            guard let contextPtr else { return }
            let service = Unmanaged<PowerMonitorService>.fromOpaque(contextPtr).takeUnretainedValue()
            Task { @MainActor in
                service.handlePowerNotification()
            }
        }, context)?.takeRetainedValue() {
            self.runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    public func stopMonitoring() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = nil
        }
    }

    deinit {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    private func handlePowerNotification() {
        let oldSnapshot = lastSnapshot
        let newSnapshot = Self.readCurrentPowerStatus()
        lastSnapshot = newSnapshot
        if oldSnapshot != newSnapshot {
            onPowerChange?(oldSnapshot, newSnapshot)
        }
    }

    /// Reads current AC power connection and battery percentage using `IOPSCopyPowerSourcesInfo`.
    public nonisolated static func readCurrentPowerStatus() -> PowerStatusSnapshot {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return PowerStatusSnapshot(isConnectedToAC: true, batteryPercentage: nil, isCharging: false)
        }

        var isAC = true
        var batteryPercent: Int? = nil
        var charging = false

        for ps in list {
            guard let desc = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            if let powerState = desc[kIOPSPowerSourceStateKey as String] as? String {
                isAC = (powerState == (kIOPSACPowerValue as String))
            }
            if let currentCap = desc[kIOPSCurrentCapacityKey as String] as? Int,
               let maxCap = desc[kIOPSMaxCapacityKey as String] as? Int,
               maxCap > 0 {
                batteryPercent = Int((Double(currentCap) / Double(maxCap) * 100.0).rounded())
            }
            if let isChg = desc[kIOPSIsChargingKey as String] as? Bool {
                charging = isChg
            }
        }

        return PowerStatusSnapshot(
            isConnectedToAC: isAC,
            batteryPercentage: batteryPercent,
            isCharging: charging
        )
    }
}
