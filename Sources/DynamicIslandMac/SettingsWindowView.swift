import SwiftUI
import AppKit

// MARK: - Settings Tab Identifier
public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case control = "Control Center"
    case music = "Music & Lyrics"
    case timer = "Timer & Clock"
    case notes = "Quick Notes"
    case devices = "Connected Devices"
    case shelf = "Shelf & Clipboard"
    case mascot = "Living Mascot"
    case appearance = "Appearance & Physics"
    case permissions = "System & Permissions"
    case about = "About NotchFlow"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .general: return "gearshape.fill"
        case .control: return "slider.horizontal.3"
        case .music: return "music.note"
        case .timer: return "timer"
        case .notes: return "checklist"
        case .devices: return "laptopcomputer.and.iphone"
        case .shelf: return "tray.full.fill"
        case .mascot: return "eyes"
        case .appearance: return "sparkles"
        case .permissions: return "lock.shield.fill"
        case .about: return "info.circle.fill"
        }
    }
    
    public var badgeColor: Color {
        switch self {
        case .general: return Color.gray
        case .control: return Color.blue
        case .music: return Color(red: 0.98, green: 0.25, blue: 0.45)
        case .timer: return Color.orange
        case .notes: return Color.yellow
        case .devices: return Color.green
        case .shelf: return Color.indigo
        case .mascot: return Color.cyan
        case .appearance: return Color.purple
        case .permissions: return Color.teal
        case .about: return Color.blue
        }
    }
}

// MARK: - Discord / macOS Modern Inset Settings View
public struct SettingsWindowView: View {
    @ObservedObject var state: IslandState = .shared
    @State private var selectedTab: SettingsTab = .general
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar (Discord / Inset Style)
            sidebarView
                .frame(width: 230)
                .background(Color(red: 0.11, green: 0.12, blue: 0.14))
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            // Right Main Content Pane
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    contentHeaderView
                    
                    switch selectedTab {
                    case .general:
                        generalSettingsView
                    case .control:
                        controlSettingsView
                    case .music:
                        musicSettingsView
                    case .timer:
                        timerSettingsView
                    case .notes:
                        notesSettingsView
                    case .devices:
                        devicesSettingsView
                    case .shelf:
                        shelfSettingsView
                    case .mascot:
                        mascotSettingsView
                    case .appearance:
                        appearanceSettingsView
                    case .permissions:
                        permissionsSettingsView
                    case .about:
                        aboutSettingsView
                    }
                    
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(red: 0.14, green: 0.15, blue: 0.18))
        }
        .frame(minWidth: 780, minHeight: 520)
        .foregroundColor(.white)
    }
    
    // MARK: - Sidebar View
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header / App Profile Card (Discord User/Server Header Style)
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.12, green: 0.52, blue: 0.98), Color(red: 0.56, green: 0.22, blue: 0.92)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("NotchFlow")
                        .font(.system(size: 14.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Settings & Modules")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))
                }
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
                .background(Color.white.opacity(0.06))
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            
            // Category List grouped safely for Swift 5.7 TupleView limits
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    Group {
                        sidebarSectionTitle("ISLAND MODULES")
                        sidebarItem(.general)
                        sidebarItem(.control)
                        sidebarItem(.music)
                        sidebarItem(.timer)
                        sidebarItem(.notes)
                        sidebarItem(.devices)
                        sidebarItem(.shelf)
                    }
                    
                    Group {
                        sidebarSectionTitle("VISUALS & BEHAVIOR")
                            .padding(.top, 10)
                        sidebarItem(.mascot)
                        sidebarItem(.appearance)
                    }
                    
                    Group {
                        sidebarSectionTitle("SYSTEM")
                            .padding(.top, 10)
                        sidebarItem(.permissions)
                        sidebarItem(.about)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 16)
            }
        }
    }
    
    private func sidebarSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.60))
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 4)
    }
    
    private func sidebarItem(_ tab: SettingsTab) -> some View {
        let isSelected = selectedTab == tab
        return Button(action: {
            selectedTab = tab
            state.triggerHaptic(.generic)
        }) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(tab.badgeColor)
                        .frame(width: 22, height: 22)
                    
                    Image(systemName: tab.iconName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.78))
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Header
    private var contentHeaderView: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selectedTab.badgeColor)
                    .frame(width: 32, height: 32)
                
                Image(systemName: selectedTab.iconName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedTab.rawValue)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Reusable Setting Card Layouts
    private func settingCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color(red: 0.18, green: 0.19, blue: 0.23))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    private func settingRow<Trailing: View>(title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 11.5, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))
                }
            }
            
            Spacer(minLength: 16)
            
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func customToggle(isOn: Binding<Bool>) -> some View {
        Toggle("", isOn: isOn)
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.20, green: 0.85, blue: 0.40)))
    }
    
    // MARK: - Subviews
    private var generalSettingsView: some View {
        VStack(spacing: 16) {
            settingCard {
                settingRow(title: "Launch at Login", subtitle: "Automatically open NotchFlow when your Mac starts up") {
                    customToggle(isOn: Binding(
                        get: { state.isLaunchAtLoginEnabled },
                        set: { _ in state.toggleLaunchAtLogin() }
                    ))
                }
                
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 16)
                
                settingRow(title: "Trackpad Haptic Feedback", subtitle: "Feel tactile feedback when interacting with island controls") {
                    customToggle(isOn: Binding(
                        get: { state.isHapticEnabled },
                        set: { state.setHapticEnabled($0) }
                    ))
                }
                
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 16)
                
                settingRow(title: "Hover Peek", subtitle: "Peek minimal island indicators when mouse approaches the notch") {
                    customToggle(isOn: $state.isHoverPeekEnabled)
                }
            }
            
            settingCard {
                settingRow(title: "Dismiss Behavior", subtitle: "Cursor Away auto-closes on mouse exit; Click Only requires tapping outside") {
                    Picker("", selection: Binding(
                        get: { state.dismissMode },
                        set: { state.setDismissMode($0) }
                    )) {
                        ForEach(DismissMode.allCases, id: \.self) { mode in
                            Text(mode == .cursorAway ? "Cursor Away" : "Click Only").tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
            }
        }
    }
    
    private var controlSettingsView: some View {
        VStack(spacing: 16) {
            settingCard {
                settingRow(title: "System Volume Level", subtitle: "Current active audio output volume") {
                    Text("\(state.currentVolume)%")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 16)
                
                settingRow(title: "Wi-Fi Status", subtitle: "Connected wireless network") {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(state.isWifiOn ? Color(red: 0.20, green: 0.85, blue: 0.40) : Color.white.opacity(0.35))
                            .frame(width: 6, height: 6)
                        Text(state.isWifiOn ? state.wifiSSID : "Turned Off")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
                }
                
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 16)
                
                settingRow(title: "Bluetooth Radio", subtitle: "Hardware radio power state") {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(state.isBluetoothOn ? Color(red: 0.0, green: 0.48, blue: 1.0) : Color.white.opacity(0.35))
                            .frame(width: 6, height: 6)
                        Text(state.isBluetoothOn ? "Enabled" : "Disabled")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
                }
            }
        }
    }
    
    private var musicSettingsView: some View {
        VStack(spacing: 16) {
            settingCard {
                settingRow(title: "Apple Music Synced Lyrics", subtitle: "Real-time synchronized karaoke lyrics powered by LRCLIB API") {
                    customToggle(isOn: $state.isLyricsEnabled)
                }
                
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 16)
                
                settingRow(title: "Now Playing Status", subtitle: "Current media player track state") {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(state.isPlaying ? Color(red: 0.20, green: 0.85, blue: 0.40) : Color.white.opacity(0.40))
                            .frame(width: 6, height: 6)
                        Text(state.isPlaying ? "Playing" : "Paused")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
                }
            }
        }
    }
    
    private var timerSettingsView: some View {
        VStack(spacing: 16) {
            settingCard {
                settingRow(title: "Timer Running Status", subtitle: "Live countdown tracking on the dynamic island bar") {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(state.isTimerRunning ? Color(red: 0.20, green: 0.85, blue: 0.40) : Color.white.opacity(0.35))
                            .frame(width: 6, height: 6)
                        Text(state.isTimerRunning ? "Running" : "Idle")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
                }
                
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 16)
                
                settingRow(title: "Selected Preset Duration", subtitle: "Target countdown duration") {
                    Text("\(state.timerSelectedMinutes) Minutes")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    private var notesSettingsView: some View {
        VStack(spacing: 16) {
            settingCard {
                settingRow(title: "Quick Reminders", subtitle: "Active checklist items stored in memory") {
                    Text("\(state.todos.count) Reminders")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    private var devicesSettingsView: some View {
        VStack(spacing: 16) {
            settingCard {
                settingRow(title: "Connected Devices HUD", subtitle: "Tracks AirPods, Keyboards, Mice, and Bluetooth accessories") {
                    Text("\(state.connectedDevices.count) Paired")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    private var shelfSettingsView: some View {
        VStack(spacing: 16) {
            settingCard {
                settingRow(title: "Clipboard History Storage", subtitle: "Total captured clipboard clippings") {
                    Text("\(state.clipboardHistory.count) Items")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 16)
                
                settingRow(title: "Clear All History", subtitle: "Erase recorded clipboard snippets from local memory") {
                    Button("Clear Clipboard") {
                        state.clearClipboard()
                        state.triggerHaptic(.generic)
                    }
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(red: 1.0, green: 0.40, blue: 0.40))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(red: 1.0, green: 0.20, blue: 0.20).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var mascotSettingsView: some View {
        VStack(spacing: 16) {
            settingCard {
                settingRow(title: "Notchy Living Mascot", subtitle: "Signature capsule cyber-eyes matching the MacBook notch geometry with organic blinking and expressions") {
                    HStack(spacing: 4.5) {
                        NotchySingleEyeView(isRightEye: false, eyelidClose: 0, happyArc: 0)
                        NotchySingleEyeView(isRightEye: true, eyelidClose: 0, happyArc: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.40))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }
    
    private var appearanceSettingsView: some View {
        VStack(spacing: 16) {
            settingCard {
                settingRow(title: "Seamless Menu Bar Tinting", subtitle: "Blends the top notch cleanly into the active wallpaper") {
                    customToggle(isOn: Binding(
                        get: { state.isSeamlessMenuBarEnabled },
                        set: { _ in state.toggleSeamlessMenuBar() }
                    ))
                }
                
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 16)
                
                settingRow(title: "Animation Physics Profile", subtitle: "Select island expansion and bounce physics profile") {
                    Picker("", selection: Binding(
                        get: { state.animationStyle },
                        set: { state.setAnimationStyle($0) }
                    )) {
                        ForEach(AnimationStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 250)
                }
                
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 16)
                
                settingRow(title: "Bounciness", subtitle: "Spring elasticity: 0.45 (bouncy) to 1.00 (rigid)") {
                    HStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { state.customBounciness },
                                set: { state.setCustomBounciness($0) }
                            ),
                            in: 0.45...1.00,
                            step: 0.01
                        )
                        .frame(width: 140)
                        
                        Text(String(format: "%.2f", state.customBounciness))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.white)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 16)
                
                settingRow(title: "Response Duration", subtitle: "Animation speed: 0.20s (snappy) to 0.55s (smooth)") {
                    HStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { state.customDuration },
                                set: { state.setCustomDuration($0) }
                            ),
                            in: 0.20...0.55,
                            step: 0.01
                        )
                        .frame(width: 140)
                        
                        Text(String(format: "%.2fs", state.customDuration))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.white)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
    }
    
    private var permissionsSettingsView: some View {
        VStack(spacing: 16) {
            settingCard {
                settingRow(title: "Notification Center Database (Full Disk Access)", subtitle: "Required to deliver WhatsApp and messaging badges directly to the Island") {
                    let hasAccess = NotificationListenerService.shared.checkDatabaseAccessibility()
                    Text(hasAccess ? "Authorized" : "Permission Needed")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(hasAccess ? .green : .orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background((hasAccess ? Color.green : Color.orange).opacity(0.15))
                        .clipShape(Capsule())
                }
                
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 16)
                
                settingRow(title: "Open Privacy & Security Settings", subtitle: "Manage macOS Permissions in System Settings") {
                    Button("Open Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(red: 0.30, green: 0.65, blue: 1.0))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var aboutSettingsView: some View {
        VStack(spacing: 16) {
            settingCard {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color(red: 0.12, green: 0.52, blue: 0.98), Color(red: 0.56, green: 0.22, blue: 0.92)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 54, height: 54)
                        
                        Image(systemName: "circle.hexagongrid.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("NotchFlow for macOS")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Version 1.0.0 Universal (Apple Silicon & Intel)")
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.72))
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 16)
                
                settingRow(title: "Developer & Creator", subtitle: "Crafted for macOS power users") {
                    Text("Ferrel")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 16)
                
                settingRow(title: "GitHub Repository", subtitle: "Source code, release notes, and community updates") {
                    Button(action: {
                        if let url = URL(string: "https://github.com/FerrelHD/Dynamic-Chemicvl") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text("GitHub")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(red: 0.30, green: 0.65, blue: 1.0))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
