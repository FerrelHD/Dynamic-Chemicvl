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
    private var selectedTab: SettingsTab { state.selectedSettingsTab }
    
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
            state.setSettingsTab(tab)
            state.triggerHaptic(.generic)
        }) {
            HStack(spacing: 9) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22, alignment: .center)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(tab.badgeColor)
                    )
                
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
            Image(systemName: selectedTab.iconName)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32, alignment: .center)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selectedTab.badgeColor)
                )
            
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
    
    // High-contrast modern dark segmented pill picker (eliminates dark text contrast collisions)
    private func segmentedPicker<T: Hashable>(
        options: [T],
        selection: Binding<T>,
        titleForOption: @escaping (T) -> String
    ) -> some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection.wrappedValue == option
                Button(action: {
                    selection.wrappedValue = option
                    state.triggerHaptic(.generic)
                }) {
                    Text(titleForOption(option))
                        .font(.system(size: 11.5, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundColor(isSelected ? Color(red: 0.12, green: 0.13, blue: 0.16) : Color.white.opacity(0.85))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isSelected ? Color.white : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2.5)
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
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
                    segmentedPicker(
                        options: DismissMode.allCases,
                        selection: Binding(
                            get: { state.dismissMode },
                            set: { state.setDismissMode($0) }
                        ),
                        titleForOption: { $0 == .cursorAway ? "Cursor Away" : "Click Only" }
                    )
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
            // Card 1: Character Identity & Visual Customization (Kategori A)
            settingCard {
                // Row 1: Master Enable / Disable Toggle
                settingRow(title: "Notchy Emoji Living Mascot", subtitle: "Living character on your notch with natural blinks, cursor gaze, and expressive animations") {
                    HStack(spacing: 12) {
                        MascotView(model: state.mascotModel, size: 22)
                            .opacity(state.isMascotEnabled ? 1.0 : 0.4)
                        
                        customToggle(isOn: Binding(
                            get: { state.isMascotEnabled },
                            set: { state.setMascotEnabled($0) }
                        ))
                    }
                }
                
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 16)
                
                // Row 2: Mascot Skin Palette (Kategori A)
                settingRow(title: "Mascot Color Skin", subtitle: "Procedural 3D surface finish & ambient bloom aura") {
                    segmentedPicker(
                        options: MascotTheme.allCases,
                        selection: Binding(
                            get: { state.mascotTheme },
                            set: { state.setMascotTheme($0) }
                        ),
                        titleForOption: { $0.shortName }
                    )
                }
                .opacity(state.isMascotEnabled ? 1.0 : 0.4)
                .disabled(!state.isMascotEnabled)
                
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 16)
                
                // Row 3: Eye Expression Style (Kategori A)
                settingRow(title: "Eye Expression Style", subtitle: "Personality style: Classic Oval, Kawaii Arcs (^_^), or Minimal Dots (••)") {
                    segmentedPicker(
                        options: MascotEyeStyle.allCases,
                        selection: Binding(
                            get: { state.mascotEyeStyle },
                            set: { state.setMascotEyeStyle($0) }
                        ),
                        titleForOption: { $0.shortName }
                    )
                }
                .opacity(state.isMascotEnabled ? 1.0 : 0.4)
                .disabled(!state.isMascotEnabled)
                
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 16)
                
                // Row 4: Glow Intensity
                settingRow(title: "Mascot Glow Intensity", subtitle: "Ambient light aura bloom: 0% (Off) to 100% (Vibrant)") {
                    HStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { state.mascotGlowIntensity },
                                set: { state.setMascotGlowIntensity($0) }
                            ),
                            in: 0.0...1.0,
                            step: 0.05
                        )
                        .frame(width: 140)
                        
                        Text("\(Int(state.mascotGlowIntensity * 100))%")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.white)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                .opacity(state.isMascotEnabled ? 1.0 : 0.4)
                .disabled(!state.isMascotEnabled)
            }
            
            // Card 2: Greeting Animation & Interactive Preview
            settingCard {
                // Row 1: Launch Greeting Animation Toggle
                settingRow(title: "Launch Greeting Animation", subtitle: "Play welcoming wave and wink sequence when NotchFlow opens") {
                    customToggle(isOn: Binding(
                        get: { state.isLaunchGreetingEnabled },
                        set: { state.setLaunchGreetingEnabled($0) }
                    ))
                }
                .opacity(state.isMascotEnabled ? 1.0 : 0.4)
                .disabled(!state.isMascotEnabled)
                
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 16)
                
                // Row 2: Replay Greeting Button
                settingRow(title: "Replay Greeting Animation", subtitle: "Preview Notchy's waving hand intro on the compact notch") {
                    Button(action: {
                        state.replayGreeting()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11, weight: .bold))
                            Text("Play Greeting")
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .opacity(state.isMascotEnabled ? 1.0 : 0.4)
                .disabled(!state.isMascotEnabled)
                
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 16)
                
                // Row 3: Interactive Live Preview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Interactive Mascot Preview")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Watch Notchy blink naturally, wink playfully (😉), glance towards your cursor, and doze off into a peaceful sleep (💤) after 2 minutes of AFK inactivity.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.60))
                    
                    MascotPreview(model: state.mascotModel)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .opacity(state.isMascotEnabled ? 1.0 : 0.4)
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
                    segmentedPicker(
                        options: AnimationStyle.allCases,
                        selection: Binding(
                            get: { state.animationStyle },
                            set: { state.setAnimationStyle($0) }
                        ),
                        titleForOption: { $0.rawValue }
                    )
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
                
                Divider().background(Color.white.opacity(0.08)).padding(.leading, 16)
                
                settingRow(title: "Restore Default Physics", subtitle: "Reset elasticity to 0.82 and speed to 0.35s fluid spring") {
                    Button(action: {
                        state.resetAnimationDefaults()
                        state.triggerHaptic(.generic)
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11, weight: .bold))
                            Text("Reset to Defaults")
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.plain)
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
            }
        }
    }
}
