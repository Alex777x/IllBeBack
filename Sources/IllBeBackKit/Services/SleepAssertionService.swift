import Foundation
import IOKit.pwr_mgt

/// Manages macOS IOKit power assertions (`IOPMAssertionCreateWithName` / `IOPMAssertionRelease`)
/// to prevent user idle display sleep or system sleep.
/// 100% compatible with the Mac App Store App Sandbox.
@MainActor
public final class SleepAssertionService {
    nonisolated(unsafe) private var assertionID: IOPMAssertionID = IOPMAssertionID(0)
    nonisolated(unsafe) public private(set) var isHoldingAssertion: Bool = false
    public private(set) var currentAllowDisplaySleep: Bool = false

    public init() {}

    /// Acquires (or updates) an IOKit sleep assertion.
    /// - Parameter allowDisplaySleep: When `false`, prevents both display and system sleep (`PreventUserIdleDisplaySleep`).
    ///   When `true`, allows the display to turn off while keeping the system CPU/network awake (`PreventUserIdleSystemSleep`).
    /// - Returns: `true` if the assertion was successfully acquired.
    @discardableResult
    public func acquireAssertion(allowDisplaySleep: Bool, reason: String = "I'll Be Back — Active Keep-Awake Session") -> Bool {
        if isHoldingAssertion {
            if currentAllowDisplaySleep == allowDisplaySleep {
                return true
            }
            releaseAssertion()
        }

        let assertionType: String = allowDisplaySleep
            ? (kIOPMAssertionTypePreventUserIdleSystemSleep as String)
            : (kIOPMAssertionTypePreventUserIdleDisplaySleep as String)

        var newID = IOPMAssertionID(0)
        let status = IOPMAssertionCreateWithName(
            assertionType as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &newID
        )

        if status == kIOReturnSuccess {
            self.assertionID = newID
            self.isHoldingAssertion = true
            self.currentAllowDisplaySleep = allowDisplaySleep
            return true
        } else {
            self.assertionID = IOPMAssertionID(0)
            self.isHoldingAssertion = false
            return false
        }
    }

    /// Releases the active IOKit power assertion if held.
    public func releaseAssertion() {
        guard isHoldingAssertion else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = IOPMAssertionID(0)
        isHoldingAssertion = false
    }

    /// Current raw `IOPMAssertionID` for diagnostics and self-tests.
    public var activeAssertionID: UInt32 {
        UInt32(assertionID)
    }

    deinit {
        if isHoldingAssertion && assertionID != 0 {
            IOPMAssertionRelease(assertionID)
        }
    }
}
