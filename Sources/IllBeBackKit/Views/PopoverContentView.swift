import SwiftUI
import AppKit

/// Root SwiftUI view inside the menu bar `NSPopover`, modeled after macOS Control Center
/// with "I'll Be Back" identity, live countdown progress, micro-unit duration pills, and 10 settings.
public struct PopoverContentView: View {
    @ObservedObject public var store: AppStore
    public let onQuit: () -> Void

    public init(store: AppStore, onQuit: @escaping () -> Void = { NSApplication.shared.terminate(nil) }) {
        self.store = store
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderSectionView(store: store)
                .padding(.horizontal, 14)
                .padding(.top, 13)
                .padding(.bottom, 11)

            ControlCenterDivider()

            DurationSectionView(store: store)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            ControlCenterDivider()

            SettingsSectionView(store: store)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            ControlCenterDivider()

            FooterSectionView(store: store, onQuit: onQuit)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .frame(width: 304)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - 1. Header Section ("I'll Be Back" + Subtitle + Switch + Progress Bar)

public struct HeaderSectionView: View {
    @ObservedObject public var store: AppStore

    public init(store: AppStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("I'll Be Back")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)

                        if store.isActive {
                            Circle()
                                .fill(store.accentColor)
                                .frame(width: 6, height: 6)
                                .shadow(color: store.accentColor.opacity(0.6), radius: 3)
                        }
                    }

                    if let subtitle = store.statusSubtitle {
                        Text(subtitle)
                            .font(.system(size: 11.5, weight: .regular))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                ControlCenterSwitchView(
                    isOn: store.isActive,
                    accentColor: store.accentColor
                ) {
                    store.toggleActive()
                }
            }

            if let progress = store.timerProgress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.10))
                            .frame(height: 3)

                        Capsule()
                            .fill(store.accentColor)
                            .frame(width: max(geo.size.width * progress, 4), height: 3)
                    }
                }
                .frame(height: 3)
            }
        }
    }
}

/// Pure SwiftUI macOS Control Center pill switch matching the reference screenshots.
public struct ControlCenterSwitchView: View {
    @Environment(\.colorScheme) private var colorScheme
    public let isOn: Bool
    public let accentColor: Color
    public let action: () -> Void

    public init(isOn: Bool, accentColor: Color, action: @escaping () -> Void) {
        self.isOn = isOn
        self.accentColor = accentColor
        self.action = action
    }

    private var trackFill: Color {
        if isOn {
            return accentColor
        }
        return Color.primary.opacity(colorScheme == .dark ? 0.20 : 0.14)
    }

    public var body: some View {
        Button(action: action) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule(style: .continuous)
                    .fill(trackFill)
                    .frame(width: 42, height: 23)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(
                                isOn ? Color.white.opacity(0.15) : Color.primary.opacity(0.10),
                                lineWidth: 0.8
                            )
                    )

                Circle()
                    .fill(Color.white)
                    .frame(width: 19, height: 19)
                    .shadow(color: Color.black.opacity(0.22), radius: 1.5, y: 0.8)
                    .padding(.horizontal, 2)
            }
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isOn)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Keep Mac Awake")
        .accessibilityValue(isOn ? "Active" : "Inactive")
    }
}

// MARK: - 2. Collapsible Duration Section (`∞` · `15m` `30m` `45m` · `1h` `4h` `8h` `12h`)

public struct DurationSectionView: View {
    @ObservedObject public var store: AppStore

    public init(store: AppStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: store.isDurationExpanded ? 10 : 0) {
            Button {
                store.isDurationExpanded.toggle()
            } label: {
                HStack {
                    Text("Duration")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(store.isDurationExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovered in
                store.hoveredElementID = hovered ? "header.duration" : nil
            }
            .opacity(store.hoveredElementID == "header.duration" ? 0.82 : 1.0)
            .accessibilityLabel("Duration Section")
            .accessibilityValue(store.isDurationExpanded ? "Expanded" : "Collapsed")

            if store.isDurationExpanded {
                HStack(spacing: 0) {
                    DurationTileButton(
                        preset: .indefinite,
                        isSelected: store.settings.selectedDuration == .indefinite && store.isActive,
                        isDefaultSelected: store.settings.selectedDuration == .indefinite && !store.isActive,
                        isHovered: store.hoveredElementID == "duration.\(DurationPreset.indefinite.rawValue)",
                        accentColor: store.accentColor,
                        onHoverChange: { hovered in
                            store.hoveredElementID = hovered ? "duration.\(DurationPreset.indefinite.rawValue)" : nil
                        },
                        action: {
                            store.selectDuration(.indefinite)
                        }
                    )

                    Spacer(minLength: 0)
                    DurationGroupDot()
                    Spacer(minLength: 0)

                    ForEach(Array(DurationPreset.minutePresets.enumerated()), id: \.element.id) { index, preset in
                        DurationTileButton(
                            preset: preset,
                            isSelected: store.settings.selectedDuration == preset && store.isActive,
                            isDefaultSelected: store.settings.selectedDuration == preset && !store.isActive,
                            isHovered: store.hoveredElementID == "duration.\(preset.rawValue)",
                            accentColor: store.accentColor,
                            onHoverChange: { hovered in
                                store.hoveredElementID = hovered ? "duration.\(preset.rawValue)" : nil
                            },
                            action: {
                                store.selectDuration(preset)
                            }
                        )
                        if index < DurationPreset.minutePresets.count - 1 {
                            Spacer(minLength: 0)
                        }
                    }

                    Spacer(minLength: 0)
                    DurationGroupDot()
                    Spacer(minLength: 0)

                    ForEach(Array(DurationPreset.hourPresets.enumerated()), id: \.element.id) { index, preset in
                        DurationTileButton(
                            preset: preset,
                            isSelected: store.settings.selectedDuration == preset && store.isActive,
                            isDefaultSelected: store.settings.selectedDuration == preset && !store.isActive,
                            isHovered: store.hoveredElementID == "duration.\(preset.rawValue)",
                            accentColor: store.accentColor,
                            onHoverChange: { hovered in
                                store.hoveredElementID = hovered ? "duration.\(preset.rawValue)" : nil
                            },
                            action: {
                                store.selectDuration(preset)
                            }
                        )
                        if index < DurationPreset.hourPresets.count - 1 {
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
                .padding(.bottom, 2)
            }
        }
    }
}

public struct DurationGroupDot: View {
    public init() {}

    public var body: some View {
        Circle()
            .fill(Color.primary.opacity(0.24))
            .frame(width: 3, height: 3)
    }
}

public struct DurationTileButton: View {
    @Environment(\.colorScheme) private var colorScheme
    public let preset: DurationPreset
    public let isSelected: Bool
    public let isDefaultSelected: Bool
    public let isHovered: Bool
    public let accentColor: Color
    public let onHoverChange: (Bool) -> Void
    public let action: () -> Void

    public init(
        preset: DurationPreset,
        isSelected: Bool,
        isDefaultSelected: Bool,
        isHovered: Bool,
        accentColor: Color,
        onHoverChange: @escaping (Bool) -> Void,
        action: @escaping () -> Void
    ) {
        self.preset = preset
        self.isSelected = isSelected
        self.isDefaultSelected = isDefaultSelected
        self.isHovered = isHovered
        self.accentColor = accentColor
        self.onHoverChange = onHoverChange
        self.action = action
    }

    private var tileBackground: Color {
        if isSelected {
            return accentColor
        }
        let baseOpacity = colorScheme == .dark ? 0.11 : 0.08
        let hoverBoost = isHovered ? 0.06 : 0.0
        return Color.primary.opacity(baseOpacity + hoverBoost)
    }

    private var textColor: Color {
        if isSelected {
            return .white
        }
        return .primary
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        Button(action: action) {
            ZStack {
                shape
                    .fill(tileBackground)
                    .overlay(
                        shape
                            .strokeBorder(
                                isDefaultSelected ? accentColor.opacity(0.55) : Color.primary.opacity(isSelected ? 0 : 0.06),
                                lineWidth: isDefaultSelected ? 1.2 : 0.6
                            )
                    )

                if let unit = preset.unitBadge {
                    Text("\(preset.primaryLabel)\(unit)")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(textColor)
                } else {
                    Text(preset.primaryLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(textColor)
                        .offset(y: -0.5)
                }
            }
            .frame(width: 29, height: 28)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover(perform: onHoverChange)
        .help(preset.accessibilityTitle)
        .accessibilityLabel("Duration \(preset.accessibilityTitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - 3. Collapsible Settings Section (3 Compact Groups with Circular Icon-Toggle Rows)

public struct SettingsSectionView: View {
    @ObservedObject public var store: AppStore

    public init(store: AppStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: store.isSettingsExpanded ? 8 : 0) {
            Button {
                store.isSettingsExpanded.toggle()
            } label: {
                HStack {
                    Text("Settings")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(store.isSettingsExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovered in
                store.hoveredElementID = hovered ? "header.settings" : nil
            }
            .opacity(store.hoveredElementID == "header.settings" ? 0.82 : 1.0)
            .accessibilityLabel("Settings Section")
            .accessibilityValue(store.isSettingsExpanded ? "Expanded" : "Collapsed")

            if store.isSettingsExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    // Group 1: Startup & Controls
                    SettingsSubheaderView(title: "General & Controls", topPadding: 2)

                    SettingToggleRowView(
                        id: "setting.login",
                        icon: "power",
                        title: "Start at login",
                        isOn: store.settings.launchAtLogin,
                        isHovered: store.hoveredElementID == "setting.login",
                        accentColor: store.accentColor,
                        onHoverChange: { store.hoveredElementID = $0 ? "setting.login" : nil },
                        action: { store.toggleLaunchAtLogin() }
                    )

                    SettingToggleRowView(
                        id: "setting.launch",
                        icon: "switch.2",
                        title: "Keep awake on launch",
                        isOn: store.settings.activateAtLaunch,
                        isHovered: store.hoveredElementID == "setting.launch",
                        accentColor: store.accentColor,
                        onHoverChange: { store.hoveredElementID = $0 ? "setting.launch" : nil },
                        action: { store.toggleActivateAtLaunch() }
                    )

                    SettingToggleRowView(
                        id: "setting.leftclick",
                        icon: "cursorarrow.click",
                        title: "Left-click toggles state",
                        isOn: store.settings.activateWithLeftClick,
                        isHovered: store.hoveredElementID == "setting.leftclick",
                        accentColor: store.accentColor,
                        onHoverChange: { store.hoveredElementID = $0 ? "setting.leftclick" : nil },
                        action: { store.toggleActivateWithLeftClick() }
                    )

                    SettingToggleRowView(
                        id: "setting.shortcut",
                        icon: "command",
                        title: "Global hotkey",
                        isOn: store.settings.globalShortcutEnabled,
                        isHovered: store.hoveredElementID == "setting.shortcut",
                        accentColor: store.accentColor,
                        onHoverChange: { store.hoveredElementID = $0 ? "setting.shortcut" : nil },
                        action: { store.toggleGlobalShortcut() }
                    ) {
                        if store.settings.globalShortcutEnabled {
                            ShortcutRecorderBadgeView(store: store)
                        }
                    }

                    // Group 2: Display & Appearance
                    SettingsSubheaderView(title: "Display & Appearance", topPadding: 6)

                    SettingToggleRowView(
                        id: "setting.displaysleep",
                        icon: "display",
                        title: "Allow display to sleep",
                        isOn: store.settings.allowDisplayToSleep,
                        isHovered: store.hoveredElementID == "setting.displaysleep",
                        accentColor: store.accentColor,
                        onHoverChange: { store.hoveredElementID = $0 ? "setting.displaysleep" : nil },
                        action: { store.toggleAllowDisplayToSleep() }
                    )

                    SettingToggleRowView(
                        id: "setting.coloricon",
                        icon: "paintpalette.fill",
                        title: "Colored menu bar icon",
                        isOn: store.settings.coloredMenuBarIcon,
                        isHovered: store.hoveredElementID == "setting.coloricon",
                        accentColor: store.accentColor,
                        onHoverChange: { store.hoveredElementID = $0 ? "setting.coloricon" : nil },
                        action: { store.toggleColoredMenuBarIcon() }
                    )

                    SettingToggleRowView(
                        id: "setting.notifications",
                        icon: "bell.fill",
                        title: "Session notifications",
                        isOn: store.settings.allowNotifications,
                        isHovered: store.hoveredElementID == "setting.notifications",
                        accentColor: store.accentColor,
                        onHoverChange: { store.hoveredElementID = $0 ? "setting.notifications" : nil },
                        action: { store.toggleAllowNotifications() }
                    )

                    // Group 3: Power & Battery
                    SettingsSubheaderView(title: "Power & Battery", topPadding: 6)

                    SettingToggleRowView(
                        id: "setting.powerconnect",
                        icon: "bolt.fill",
                        title: "Enable when charging",
                        isOn: store.settings.activateOnPowerConnect,
                        isHovered: store.hoveredElementID == "setting.powerconnect",
                        accentColor: store.accentColor,
                        onHoverChange: { store.hoveredElementID = $0 ? "setting.powerconnect" : nil },
                        action: { store.toggleActivateOnPowerConnect() }
                    )

                    SettingToggleRowView(
                        id: "setting.powerdisconnect",
                        icon: "bolt.slash.fill",
                        title: "Disable on battery power",
                        isOn: store.settings.deactivateOnPowerDisconnect,
                        isHovered: store.hoveredElementID == "setting.powerdisconnect",
                        accentColor: store.accentColor,
                        onHoverChange: { store.hoveredElementID = $0 ? "setting.powerdisconnect" : nil },
                        action: { store.toggleDeactivateOnPowerDisconnect() }
                    )

                    SettingToggleRowView(
                        id: "setting.lowbattery",
                        icon: "battery.25",
                        title: "Auto-pause below 20%",
                        isOn: store.settings.pauseOnLowBattery,
                        isHovered: store.hoveredElementID == "setting.lowbattery",
                        accentColor: store.accentColor,
                        onHoverChange: { store.hoveredElementID = $0 ? "setting.lowbattery" : nil },
                        action: { store.togglePauseOnLowBattery() }
                    )
                }
                .padding(.top, 2)
                .padding(.bottom, 2)
            }
        }
    }
}

public struct SettingsSubheaderView: View {
    public let title: String
    public let topPadding: CGFloat

    public init(title: String, topPadding: CGFloat = 4) {
        self.title = title
        self.topPadding = topPadding
    }

    public var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .tracking(0.5)
            .foregroundStyle(.secondary.opacity(0.78))
            .padding(.top, topPadding)
            .padding(.bottom, 1)
    }
}

public struct SettingToggleRowView<TrailingContent: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    public let id: String
    public let icon: String
    public let title: String
    public let isOn: Bool
    public let isHovered: Bool
    public let accentColor: Color
    public let onHoverChange: (Bool) -> Void
    public let action: () -> Void
    @ViewBuilder public let trailingContent: () -> TrailingContent

    public init(
        id: String,
        icon: String,
        title: String,
        isOn: Bool,
        isHovered: Bool,
        accentColor: Color,
        onHoverChange: @escaping (Bool) -> Void,
        action: @escaping () -> Void,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent = { EmptyView() }
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.isOn = isOn
        self.isHovered = isHovered
        self.accentColor = accentColor
        self.onHoverChange = onHoverChange
        self.action = action
        self.trailingContent = trailingContent
    }

    private var circleFill: Color {
        if isOn {
            return accentColor
        }
        return Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08)
    }

    private var iconForeground: Color {
        if isOn {
            return .white
        }
        return .primary.opacity(0.78)
    }

    public var body: some View {
        HStack(spacing: 10) {
            Button(action: action) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(circleFill)
                            .frame(width: 26, height: 26)

                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(iconForeground)
                    }

                    Text(title)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.primary.opacity(isHovered ? 1.0 : 0.92))
                        .lineLimit(1)

                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isOn ? "On" : "Off")

            trailingContent()
        }
        .padding(.vertical, 1.5)
        .onHover(perform: onHoverChange)
    }
}

/// Interactive badge on the "Global keyboard shortcut" row allowing 1-click key recording.
public struct ShortcutRecorderBadgeView: View {
    @ObservedObject public var store: AppStore

    public init(store: AppStore) {
        self.store = store
    }

    public var body: some View {
        Button {
            store.toggleRecordingShortcut()
        } label: {
            Text(store.isRecordingShortcut ? "Press keys…" : store.settings.shortcutConfig.displayString)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(store.isRecordingShortcut ? store.accentColor : .secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(
                                    store.isRecordingShortcut ? store.accentColor : Color.primary.opacity(0.12),
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
        .help("Click to record a new global keyboard shortcut")
    }
}

// MARK: - 4. Footer Section (GitHub + About + Quit)

public struct FooterSectionView: View {
    @ObservedObject public var store: AppStore
    public let onQuit: () -> Void

    public init(store: AppStore, onQuit: @escaping () -> Void) {
        self.store = store
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            GitHubRepoRowButton(
                isHovered: store.hoveredElementID == "footer.github",
                onHoverChange: { store.hoveredElementID = $0 ? "footer.github" : nil }
            ) {
                store.openGitHubRepo()
            }
            .padding(.bottom, 2)

            FooterMenuRowButton(
                title: "About",
                isHovered: store.hoveredElementID == "footer.about",
                onHoverChange: { store.hoveredElementID = $0 ? "footer.about" : nil }
            ) {
                store.showingAbout.toggle()
            }

            if store.showingAbout {
                InlineAboutCardView(store: store)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
            }

            FooterMenuRowButton(
                title: "Quit",
                isHovered: store.hoveredElementID == "footer.quit",
                onHoverChange: { store.hoveredElementID = $0 ? "footer.quit" : nil }
            ) {
                store.deactivate()
                onQuit()
            }
        }
    }
}

public struct GitHubRepoRowButton: View {
    @Environment(\.colorScheme) private var colorScheme
    public let isHovered: Bool
    public let onHoverChange: (Bool) -> Void
    public let action: () -> Void

    public init(
        isHovered: Bool,
        onHoverChange: @escaping (Bool) -> Void,
        action: @escaping () -> Void
    ) {
        self.isHovered = isHovered
        self.onHoverChange = onHoverChange
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("GitHub · Open Source")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "star.fill")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.0))
                    .scaleEffect(isHovered ? 1.12 : 1.0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(isHovered ? (colorScheme == .dark ? 0.14 : 0.10) : (colorScheme == .dark ? 0.08 : 0.05)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isHovered ? 0.22 : 0.10), lineWidth: 0.8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover(perform: onHoverChange)
        .help("View source code & support the project on GitHub — github.com/Alex777x/IllBeBack")
        .accessibilityLabel("GitHub Open Source Repository")
    }
}

public struct FooterMenuRowButton: View {
    public let title: String
    public let isHovered: Bool
    public let onHoverChange: (Bool) -> Void
    public let action: () -> Void

    public init(
        title: String,
        isHovered: Bool,
        onHoverChange: @escaping (Bool) -> Void,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isHovered = isHovered
        self.onHoverChange = onHoverChange
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover(perform: onHoverChange)
    }
}

public struct InlineAboutCardView: View {
    @ObservedObject public var store: AppStore

    public init(store: AppStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                CyberVisorEmblemView(
                    isActive: store.isActive,
                    isColored: store.settings.coloredMenuBarIcon,
                    size: 42
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("I'll Be Back")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text("v1.0.0 · MIT")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                            )
                    }

                    Text("Free & Open-Source Keep-Awake Utility")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Text("© 2026 Anatoli Aliaksandrou")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)
            }

            Button {
                store.openGitHubRepo()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 10.5, weight: .semibold))
                    Text("github.com/Alex777x/IllBeBack")
                        .font(.system(size: 11, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Shared Visual Building Blocks

public struct ControlCenterDivider: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.09))
            .frame(height: 1)
            .padding(.horizontal, 14)
    }
}
