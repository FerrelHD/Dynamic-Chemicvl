import SwiftUI
import AppKit

public struct DynamicIslandView: View {
    @ObservedObject var state: IslandState
    @State private var isDropTargeted = false
    
    public init(state: IslandState = .shared) {
        self.state = state
    }
    
    // MARK: - Dynamic Adaptive Dimensions (Content-Hugging & Responsive)
    private var islandWidth: CGFloat {
        if state.isShowingVolumeHUD {
            return 250
        }
        if state.isShowingBatteryHUD {
            return 224
        }
        if state.isShowingCapsLockHUD {
            return 185
        }
        switch state.mode {
        case .compact:
            if state.isTimerRunning {
                return 165
            } else if state.isPlaying {
                // Responsively adapt width to track title length (min 195, max 235)
                let titleLen = CGFloat(state.trackTitle.count)
                return max(195, min(235, 165 + titleLen * 3.0))
            } else {
                return 126 // Perfectly proportioned for centered clock
            }
        case .expanded:
            return 385 // Balanced proportion on 13" and larger screens
        }
    }
    
    private var islandHeight: CGFloat {
        if state.isShowingVolumeHUD || state.isShowingBatteryHUD || state.isShowingCapsLockHUD {
            return 36
        }
        switch state.mode {
        case .compact:
            return 34
        case .expanded:
            // Dynamic content-aware height: eliminates dead space per tab!
            switch state.activeTab {
            case .music:
                return 172 // Snugly hugs cover art, timeline, and controls
            case .control:
                return 216 // Fits 2x2 squircle grid, CPU/RAM stats, and volume capsule
            case .notes:
                return 196 // Fits input bar, task list, and footer
            case .shelf:
                return 180 // Fits segment switcher, drop zone/clipboard list, and footer
            }
        }
    }
    
    private var cornerRadius: CGFloat {
        if state.isShowingVolumeHUD || state.isShowingBatteryHUD || state.isShowingCapsLockHUD {
            return 18
        }
        switch state.mode {
        case .compact:
            return islandHeight / 2 // Perfect pill
        case .expanded:
            return 26 // iOS continuous squircle curvature
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                if state.isIslandVisible {
                    // MARK: - OLED Jet-Black Pill with iOS Specular Rim
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.black)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                        )
                        .shadow(color: Color.black.opacity(0.55), radius: 16, x: 0, y: 8)
                        .overlay(
                            Group {
                                if state.isShowingVolumeHUD {
                                    volumeHUDContent
                                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                } else if state.isShowingBatteryHUD {
                                    batteryHUDContent
                                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                } else if state.isShowingCapsLockHUD {
                                    capsLockHUDContent
                                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                } else {
                                    switch state.mode {
                                    case .compact:
                                        compactContent
                                            .transition(.opacity)
                                    case .expanded:
                                        expandedContent
                                            .transition(.opacity)
                                    }
                                }
                            }
                        )
                        .frame(width: islandWidth, height: islandHeight)
                        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .onTapGesture {
                            state.toggleExpand()
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                } else {
                    // MARK: - Tucked Handle (3.5pt Micro-Pill at Top Bezel)
                    Capsule()
                        .fill(Color.black.opacity(0.82))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                        )
                        .frame(width: 44, height: 3.5)
                        .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: state.isIslandVisible)
            .animation(.spring(response: 0.34, dampingFraction: 0.78), value: state.mode)
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: state.activeTab)
            .animation(.spring(response: 0.30, dampingFraction: 0.76), value: state.isPlaying)
            .animation(.spring(response: 0.28, dampingFraction: 0.80), value: state.isShowingVolumeHUD)
            .animation(.spring(response: 0.28, dampingFraction: 0.80), value: state.isShowingBatteryHUD)
            .animation(.spring(response: 0.28, dampingFraction: 0.80), value: state.isShowingCapsLockHUD)
            .animation(.spring(response: 0.28, dampingFraction: 0.80), value: state.shelfSegment)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 4)
    }
    
    // MARK: - iOS Volume HUD (Hardware keys trigger)
    private var volumeHUDContent: some View {
        HStack(spacing: 12) {
            Image(systemName: volumeIcon)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 18)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.20))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(0, geo.size.width * CGFloat(state.currentVolume) / 100.0), height: 6)
                }
                .frame(height: geo.size.height)
            }
            .frame(height: 6)
            
            Text("\(state.currentVolume)%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 16)
    }
    
    private var volumeIcon: String {
        if state.currentVolume == 0 { return "speaker.slash.fill" }
        if state.currentVolume < 33 { return "speaker.wave.1.fill" }
        if state.currentVolume < 66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
    
    // MARK: - iOS MagSafe Battery HUD Live Activity
    private var batteryHUDContent: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(state.isBatteryCharging ? Color(red: 0.18, green: 0.85, blue: 0.38) : (state.batteryLevel <= 20 ? Color.red : Color.white.opacity(0.20)))
                    .frame(width: 24, height: 24)
                
                Image(systemName: state.isBatteryCharging ? "bolt.fill" : (state.isPowerPlugged ? "powerplug.fill" : "battery.75"))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(state.isBatteryCharging ? .black : .white)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(state.isBatteryCharging ? "MagSafe Charging" : (state.isPowerPlugged ? "Power Connected" : "On Battery"))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(state.isBatteryCharging ? "Fast Charging" : "\(state.batteryLevel)% Remaining")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.70))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Battery Level Bar Capsule
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 38, height: 14)
                
                Capsule()
                    .fill(state.isBatteryCharging ? Color(red: 0.18, green: 0.85, blue: 0.38) : (state.batteryLevel <= 20 ? Color.red : Color.white))
                    .frame(width: max(4, 38 * CGFloat(state.batteryLevel) / 100.0), height: 14)
                
                Text("\(state.batteryLevel)%")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundColor(state.batteryLevel > 60 ? .black : .white)
                    .frame(width: 38, alignment: .center)
            }
        }
        .padding(.horizontal, 14)
    }
    
    // MARK: - Caps Lock Floating HUD
    private var capsLockHUDContent: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(state.isCapsLockOn ? Color.orange : Color.white.opacity(0.18))
                    .frame(width: 24, height: 24)
                
                Image(systemName: "capslock.fill")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(state.isCapsLockOn ? .black : .white)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(state.isCapsLockOn ? "Caps Lock On" : "Caps Lock Off")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(state.isCapsLockOn ? "ABC Uppercase" : "abc Lowercase")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.70))
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 14)
    }
    
    // MARK: - 1. Compact View (Centered Clock & Responsive Media Pill)
    private var compactContent: some View {
        HStack(spacing: 0) {
            Spacer()
            
            if state.isTimerRunning {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    
                    Text(state.timerFormattedString)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Image(systemName: "timer")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.clear)
                }
            } else if state.isPlaying {
                HStack(spacing: 7) {
                    if let art = state.artworkImage {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 16, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.pink)
                    }
                    
                    Text(state.trackTitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    waveformView(height: 12)
                }
            } else {
                // Symmetrically Balanced: Numbers are DEAD-CENTER in the capsule
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                    
                    Text(currentShortTime)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    // Invisible mirror icon so the clock digits sit at the exact dead center
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.clear)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
    }
    
    // MARK: - 2. Expanded View (iOS Responsive Card)
    private var expandedContent: some View {
        VStack(spacing: 8) {
            // iOS Segmented Tab Bar Header (Responsive & Non-wrapping)
            HStack(spacing: 3) {
                ForEach(IslandTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                            state.activeTab = tab
                        }
                    }) {
                        HStack(spacing: 4) {
                            tabIcon(for: tab)
                            
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: state.activeTab == tab ? .bold : .medium, design: .rounded))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            
                            if let badge = tabBadgeCount(for: tab), badge > 0 {
                                Text("\(badge)")
                                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(state.activeTab == tab ? Color.white.opacity(0.32) : Color.white.opacity(0.18))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 4.5)
                        .padding(.horizontal, 7)
                        .background(
                            ZStack {
                                if state.activeTab == tab {
                                    Capsule()
                                        .fill(Color.white.opacity(0.20))
                                        .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 1)
                                }
                            }
                        )
                        .foregroundColor(state.activeTab == tab ? .white : .white.opacity(0.60))
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Collapse button
                Button(action: {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                        state.mode = .compact
                    }
                }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                        .padding(5.5)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // Tab Contents
            switch state.activeTab {
            case .control:
                controlTabView
            case .music:
                musicTabView
            case .notes:
                notesTabView
            case .shelf:
                shelfTabView
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 12)
    }
    
    // MARK: - Tab 1: Control Center (iOS Style Tiles)
    private var controlTabView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Wi-Fi Tile
                controlTile(
                    icon: "wifi",
                    title: "Wi-Fi",
                    subtitle: state.wifiSSID,
                    isActive: state.isWifiOn,
                    activeColor: Color(red: 0.0, green: 0.48, blue: 1.0)
                ) {
                    state.toggleWifi()
                }
                
                // Bluetooth Tile
                controlTile(
                    icon: "dot.radiowaves.left.and.right",
                    title: "Bluetooth",
                    subtitle: state.isBluetoothOn ? "On" : "Off",
                    isActive: state.isBluetoothOn,
                    activeColor: Color(red: 0.0, green: 0.48, blue: 1.0)
                ) {
                    state.toggleBluetooth()
                }
            }
            
            HStack(spacing: 6) {
                // Focus / DND Tile
                controlTileCompact(
                    icon: "moon.fill",
                    title: "Focus",
                    subtitle: state.isDNDOn ? "DND On" : "Off",
                    isActive: state.isDNDOn,
                    activeColor: Color(red: 0.35, green: 0.34, blue: 0.84)
                ) {
                    state.toggleDND()
                }
                
                // Keep Awake (Caffeinate ☕) Tile
                controlTileCompact(
                    icon: "cup.and.saucer.fill",
                    title: "Awake",
                    subtitle: state.isCaffeinated ? "Active" : "Normal",
                    isActive: state.isCaffeinated,
                    activeColor: Color(red: 0.96, green: 0.55, blue: 0.15)
                ) {
                    state.toggleCaffeinate()
                }
                
                // Focus Timer Tile
                controlTileCompact(
                    icon: "timer",
                    title: "Timer",
                    subtitle: state.isTimerRunning ? state.timerFormattedString : "25m",
                    isActive: state.isTimerRunning,
                    activeColor: Color(red: 1.0, green: 0.58, blue: 0.0)
                ) {
                    state.toggleTimer()
                }
            }
            
            // Real-time Mini System Stats (CPU & RAM)
            HStack(spacing: 8) {
                // CPU Meter
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(state.cpuUsage > 75 ? .red : (state.cpuUsage > 45 ? .orange : Color(red: 0.18, green: 0.85, blue: 0.38)))
                    
                    Text("CPU")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Text("\(state.cpuUsage)%")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                // RAM Meter
                HStack(spacing: 6) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(state.ramPercent > 85 ? .red : (state.ramPercent > 65 ? .orange : Color(red: 0.0, green: 0.48, blue: 1.0)))
                    
                    Text("RAM")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Text(String(format: "%.1f/%.0fGB", state.ramUsageGB, state.ramTotalGB))
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            
            // iOS Control Center Style Volume Slider Capsule
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                    
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(24, geo.size.width * CGFloat(state.currentVolume) / 100.0))
                    
                    HStack {
                        Image(systemName: volumeIcon)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(state.currentVolume > 15 ? Color.black.opacity(0.75) : Color.white)
                            .padding(.leading, 10)
                        
                        Spacer()
                        
                        Text("\(state.currentVolume)%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(state.currentVolume > 85 ? Color.black.opacity(0.75) : Color.white)
                            .padding(.trailing, 10)
                    }
                }
                .contentShape(Capsule())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            let fraction = max(0, min(1.0, val.location.x / geo.size.width))
                            state.updateVolume(Int(fraction * 100))
                        }
                )
            }
            .frame(height: 24)
            .padding(.top, 2)
        }
    }
    
    private func controlTile(icon: String, title: String, subtitle: String, isActive: Bool, activeColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isActive ? activeColor : Color.white.opacity(0.18))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.70))
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.09))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.75)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private func controlTileCompact(icon: String, title: String, subtitle: String, isActive: Bool, activeColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isActive ? activeColor : Color.white.opacity(0.18))
                        .frame(width: 26, height: 26)
                    
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.70))
                        .lineLimit(1)
                }
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.09))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.75)
            )
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Tab 2: Now Playing (iOS Live Activity Style)
    private var musicTabView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 11) {
                ZStack {
                    if let art = state.artworkImage {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color(red: 0.95, green: 0.2, blue: 0.45), Color(red: 0.5, green: 0.1, blue: 0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "music.note")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.4), radius: 4)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.trackTitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(state.artistName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                }
                
                Spacer()
                
                waveformView(height: 18)
            }
            
            // Progress Bar & Timestamps
            VStack(spacing: 2) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                            .frame(height: 3.5)
                        
                        Capsule()
                            .fill(Color.white)
                            .frame(width: max(0, geo.size.width * CGFloat(state.playbackProgress)), height: 3.5)
                    }
                }
                .frame(height: 3.5)
                
                HStack {
                    Text(state.currentTime)
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                    
                    Spacer()
                    
                    Text(state.totalDuration)
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                }
            }
            
            // iOS Media Controls
            HStack(spacing: 26) {
                Button(action: { state.previousTrack() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
                
                // Prominent Play/Pause Button
                Button(action: { state.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 34, height: 34)
                        
                        Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                    }
                }
                .buttonStyle(.plain)
                
                Button(action: { state.nextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                HStack(spacing: 4.5) {
                    Image(systemName: volumeIcon)
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                    Text("\(state.currentVolume)%")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 7.5)
                .padding(.vertical, 3.5)
                .background(Color.white.opacity(0.10))
                .clipShape(Capsule())
            }
        }
    }
    
    // MARK: - Tab 3: Reminders & Notes (iOS Reminders Style)
    private var notesTabView: some View {
        VStack(spacing: 7) {
            // Input field with iOS Add button
            HStack(spacing: 8) {
                TextField("Add a reminder or note...", text: $state.newTodoText, onCommit: {
                    state.addTodo()
                })
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                
                Button(action: {
                    state.addTodo()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        Text("Add")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(Color(red: 0.0, green: 0.48, blue: 1.0))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(state.newTodoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(state.newTodoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1.0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            // Scrollable List
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4.5) {
                    ForEach(state.todos) { todo in
                        HStack(spacing: 8) {
                            Button(action: { state.toggleTodo(id: todo.id) }) {
                                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                    .foregroundColor(todo.isDone ? Color.blue : Color.white.opacity(0.45))
                            }
                            .buttonStyle(.plain)
                            
                            Text(todo.text)
                                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                .foregroundColor(todo.isDone ? .white.opacity(0.45) : .white)
                                .strikethrough(todo.isDone, color: .white.opacity(0.45))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Button(action: { state.deleteTodo(id: todo.id) }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.40))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4.5)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            .frame(height: 72)
            
            // Footer Info
            HStack {
                let remaining = state.todos.filter { !$0.isDone }.count
                Text("\(remaining) task\(remaining == 1 ? "" : "s") remaining")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.60))
                
                Spacer()
                
                if state.todos.contains(where: { $0.isDone }) {
                    Button(action: { state.clearCompletedTodos() }) {
                        Text("Clear Completed")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundColor(Color.orange)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Tab 4: File Shelf & Quick Clipboard
    private var shelfTabView: some View {
        VStack(spacing: 7) {
            // Segment Switcher: Files | Clipboard
            HStack(spacing: 5) {
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        state.shelfSegment = 0
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        Text("Files Shelf")
                            .font(.system(size: 10, weight: state.shelfSegment == 0 ? .bold : .medium, design: .rounded))
                        if !state.shelfFiles.isEmpty {
                            Text("\(state.shelfFiles.count)")
                                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 0.5)
                                .background(Color.white.opacity(0.25))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(state.shelfSegment == 0 ? Color.white.opacity(0.22) : Color.white.opacity(0.06))
                    .foregroundColor(state.shelfSegment == 0 ? .white : .white.opacity(0.55))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        state.shelfSegment = 1
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.clipboard.fill")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        Text("Clipboard")
                            .font(.system(size: 10, weight: state.shelfSegment == 1 ? .bold : .medium, design: .rounded))
                        if !state.clipboardHistory.isEmpty {
                            Text("\(state.clipboardHistory.count)")
                                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 0.5)
                                .background(Color.white.opacity(0.25))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(state.shelfSegment == 1 ? Color.white.opacity(0.22) : Color.white.opacity(0.06))
                    .foregroundColor(state.shelfSegment == 1 ? .white : .white.opacity(0.55))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            
            if state.shelfSegment == 0 {
                filesShelfContent
            } else {
                clipboardHistoryContent
            }
        }
    }
    
    private var filesShelfContent: some View {
        VStack(spacing: 7) {
            if state.shelfFiles.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [5]))
                        .fill(isDropTargeted ? Color.green : Color.white.opacity(0.25))
                    
                    VStack(spacing: 3) {
                        Image(systemName: "tray.and.arrow.down")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.70))
                        Text("Drop files here for quick shelf")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                        Text("Drag out to any app or email anytime")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.50))
                    }
                }
                .frame(height: 72)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(Array(state.shelfFiles.enumerated()), id: \.element) { idx, url in
                            HStack(spacing: 6) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                
                                Text(url.lastPathComponent)
                                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Button(action: { state.removeFile(at: idx) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .onDrag { NSItemProvider(contentsOf: url)! }
                        }
                    }
                }
                .frame(height: 48)
                
                HStack {
                    Text("\(state.shelfFiles.count) file\(state.shelfFiles.count == 1 ? "" : "s") ready to drag out")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                    Spacer()
                    Button(action: { state.clearShelf() }) {
                        Text("Clear All")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onDrop(of: ["public.file-url"], isTargeted: $isDropTargeted) { providers in
            var loadedUrls: [URL] = []
            let group = DispatchGroup()
            
            for provider in providers {
                group.enter()
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                    defer { group.leave() }
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        loadedUrls.append(url)
                    } else if let url = item as? URL {
                        loadedUrls.append(url)
                    }
                }
            }
            
            group.notify(queue: .main) {
                state.addFiles(loadedUrls)
            }
            return true
        }
    }
    
    private var clipboardHistoryContent: some View {
        VStack(spacing: 7) {
            if state.clipboardHistory.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                    
                    VStack(spacing: 3) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.50))
                        Text("Clipboard history is empty")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                        Text("Copied texts will automatically appear here")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.50))
                    }
                }
                .frame(height: 72)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4.5) {
                        ForEach(Array(state.clipboardHistory.enumerated()), id: \.offset) { idx, item in
                            Button(action: {
                                state.copyClip(at: idx)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: state.copiedClipIndex == idx ? "checkmark.circle.fill" : "doc.text")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(state.copiedClipIndex == idx ? Color.green : Color.white.opacity(0.50))
                                    
                                    Text(item.replacingOccurrences(of: "\n", with: " "))
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    if state.copiedClipIndex == idx {
                                        Text("Copied!")
                                            .font(.system(size: 9, weight: .bold, design: .rounded))
                                            .foregroundColor(Color.green)
                                    } else {
                                        Text("Copy")
                                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white.opacity(0.40))
                                    }
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(state.copiedClipIndex == idx ? 0.18 : 0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 72)
                
                HStack {
                    Text("\(state.clipboardHistory.count) item\(state.clipboardHistory.count == 1 ? "" : "s") in history")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.60))
                    Spacer()
                    Button(action: { state.clearClipboard() }) {
                        Text("Clear All")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundColor(.red.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Helpers
    private func tabIcon(for tab: IslandTab) -> some View {
        switch tab {
        case .control:
            return Image(systemName: "slider.horizontal.3").font(.system(size: 9.5, weight: .bold, design: .rounded))
        case .music:
            return Image(systemName: "music.note").font(.system(size: 9.5, weight: .bold, design: .rounded))
        case .notes:
            return Image(systemName: "checklist").font(.system(size: 9.5, weight: .bold, design: .rounded))
        case .shelf:
            return Image(systemName: "tray.fill").font(.system(size: 9.5, weight: .bold, design: .rounded))
        }
    }
    
    private func tabBadgeCount(for tab: IslandTab) -> Int? {
        switch tab {
        case .notes:
            let count = state.todos.filter { !$0.isDone }.count
            return count > 0 ? count : nil
        case .shelf:
            let count = state.shelfSegment == 0 ? state.shelfFiles.count : state.clipboardHistory.count
            return count > 0 ? count : nil
        default:
            return nil
        }
    }
    
    private func waveformView(height: CGFloat) -> some View {
        HStack(spacing: 2.2) {
            ForEach(0..<state.waveHeights.count, id: \.self) { idx in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 0.18, green: 0.85, blue: 0.38))
                    .frame(width: 2.2, height: max(3, height * state.waveHeights[idx]))
            }
        }
    }
    
    private var currentShortTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}
