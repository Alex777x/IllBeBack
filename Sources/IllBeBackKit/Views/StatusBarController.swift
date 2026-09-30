import AppKit
import SwiftUI

/// Manages the macOS menu bar `NSStatusItem` and `NSPopover`, supporting both normal click behavior
/// and swapped Left-Click / Right-Click behavior when "Activate with left click" is enabled.
@MainActor
public final class StatusBarController: NSObject {
    public let store: AppStore
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var hostingController: NSHostingController<PopoverContentView>!
    nonisolated(unsafe) private var globalClickMonitor: Any?
    private var lastRenderedActive: Bool?
    private var lastRenderedColored: Bool?
    private var cachedMenuBarImage: NSImage?

    public init(store: AppStore) {
        self.store = store
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        super.init()

        configurePopover()
        configureStatusButton()

        store.onStateChanged = { [weak self] in
            self?.updateStatusButtonAppearance()
        }
        updateStatusButtonAppearance()
    }

    deinit {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        let rootView = PopoverContentView(store: store) { [weak self] in
            self?.popover.performClose(nil)
            NSApplication.shared.terminate(nil)
        }
        let controller = NSHostingController(rootView: rootView)
        controller.sizingOptions = [.preferredContentSize]
        self.hostingController = controller
        popover.contentViewController = controller
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleStatusBarClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.setAccessibilityTitle("I'll Be Back")
    }

    public func updateStatusButtonAppearance() {
        guard let button = statusItem.button else { return }
        let currentActive = store.isActive
        let currentColored = store.settings.coloredMenuBarIcon

        if cachedMenuBarImage == nil || lastRenderedActive != currentActive || lastRenderedColored != currentColored {
            let img = CyberVisorIcon.makeMenuBarImage(
                isActive: currentActive,
                isColored: currentColored
            )
            cachedMenuBarImage = img
            lastRenderedActive = currentActive
            lastRenderedColored = currentColored
            button.image = img
        }

        if let subtitle = store.statusSubtitle {
            button.toolTip = "I'll Be Back — \(subtitle)"
        } else {
            button.toolTip = "I'll Be Back — Inactive"
        }
    }

    @objc private func handleStatusBarClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRightClick = (event?.type == .rightMouseUp) ||
            (event?.modifierFlags.contains(.control) == true)

        if store.settings.activateWithLeftClick {
            if isRightClick {
                togglePopover(sender: sender)
            } else {
                store.toggleActive()
            }
        } else {
            if isRightClick {
                store.toggleActive()
            } else {
                togglePopover(sender: sender)
            }
        }
    }

    public func togglePopover(sender: NSStatusBarButton? = nil) {
        guard let button = sender ?? statusItem.button else { return }
        if popover.isShown {
            closePopover()
        } else {
            showPopover(relativeTo: button)
        }
    }

    public func showPopover(relativeTo button: NSStatusBarButton) {
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()

        if globalClickMonitor == nil {
            globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                Task { @MainActor in
                    self?.closePopover()
                }
            }
        }
    }

    public func closePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
        store.stopRecordingShortcut()
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }
}
