import Foundation
import Carbon.HIToolbox
import AppKit

/// Registers a system-wide global keyboard shortcut using Carbon `RegisterEventHotKey`,
/// which works natively inside the Mac App Store App Sandbox without requiring Accessibility permissions.
@MainActor
public final class GlobalShortcutService {
    nonisolated(unsafe) private var hotKeyRef: EventHotKeyRef?
    nonisolated(unsafe) private var eventHandlerRef: EventHandlerRef?
    public var onShortcutTriggered: (() -> Void)?

    public init() {}

    public func register(config: KeyboardShortcutConfig) {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let service = Unmanaged<GlobalShortcutService>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in
                    service.onShortcutTriggered?()
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        guard handlerStatus == noErr else { return }

        let hotKeyID = EventHotKeyID(signature: OSType(0x4942424B), id: 1) // 'IBBK'
        var ref: EventHotKeyRef?
        let regStatus = RegisterEventHotKey(
            config.keyCode,
            config.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if regStatus == noErr {
            self.hotKeyRef = ref
        } else if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    public func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    /// Key codes for standalone modifier keys that should not be recorded as a hotkey trigger.
    private static let modifierKeyCodes: Set<UInt16> = [
        54, 55, // Right/Left Command
        56, 60, // Left/Right Shift
        57,     // Caps Lock
        58, 61, // Left/Right Option
        59, 62, // Left/Right Control
        63      // Function (fn)
    ]

    /// Converts an `NSEvent` key press into a `KeyboardShortcutConfig` when recording a new shortcut.
    public static func shortcutConfig(from event: NSEvent) -> KeyboardShortcutConfig? {
        guard !modifierKeyCodes.contains(event.keyCode) else { return nil }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // Require at least Command or Control so normal typing keys (like Shift+Letter or Option+Letter) aren't hijacked
        guard flags.contains(.command) || flags.contains(.control) else { return nil }

        var carbonMods: UInt32 = 0
        if flags.contains(.control) { carbonMods |= UInt32(controlKey) }
        if flags.contains(.option) { carbonMods |= UInt32(optionKey) }
        if flags.contains(.shift) { carbonMods |= UInt32(shiftKey) }
        if flags.contains(.command) { carbonMods |= UInt32(cmdKey) }

        let chars = event.charactersIgnoringModifiers?.uppercased() ?? ""
        let cleanChar = chars.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanChar.isEmpty else { return nil }

        return KeyboardShortcutConfig(
            keyCode: UInt32(event.keyCode),
            carbonModifiers: carbonMods,
            keyDisplay: cleanChar
        )
    }
}
