import SwiftUI
import AppKit

// MARK: - MacBook Hardware Notch Cutout Shape with Quadratic Bézier Ears (Flush with Top Bezel)
public struct NotchShape: Shape {
    public var earRadius: CGFloat = 8
    public var bottomRadius: CGFloat = 14
    
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(earRadius, bottomRadius) }
        set {
            earRadius = newValue.first
            bottomRadius = newValue.second
        }
    }
    
    public init(earRadius: CGFloat = 8, bottomRadius: CGFloat = 14) {
        self.earRadius = earRadius
        self.bottomRadius = bottomRadius
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let e = max(0, min(earRadius, rect.width / 4))
        let b = max(0, min(bottomRadius, min((rect.width - 2 * e) / 2, rect.height)))
        
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        
        // Top-left concave ear fillet
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + e, y: rect.minY + e),
            control: CGPoint(x: rect.minX + e, y: rect.minY)
        )
        
        // Left vertical edge
        path.addLine(to: CGPoint(x: rect.minX + e, y: rect.maxY - b))
        
        // Bottom-left convex squircle corner
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + e + b, y: rect.maxY),
            control: CGPoint(x: rect.minX + e, y: rect.maxY)
        )
        
        // Bottom horizontal edge
        path.addLine(to: CGPoint(x: rect.maxX - e - b, y: rect.maxY))
        
        // Bottom-right convex squircle corner
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - e, y: rect.maxY - b),
            control: CGPoint(x: rect.maxX - e, y: rect.maxY)
        )
        
        // Right vertical edge
        path.addLine(to: CGPoint(x: rect.maxX - e, y: rect.minY + e))
        
        // Top-right concave ear fillet
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - e, y: rect.minY)
        )
        
        // Top straight edge flush with display bezel
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

public struct NotchOutlineShape: Shape {
    public var earRadius: CGFloat = 8
    public var bottomRadius: CGFloat = 14
    
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(earRadius, bottomRadius) }
        set {
            earRadius = newValue.first
            bottomRadius = newValue.second
        }
    }
    
    public init(earRadius: CGFloat = 8, bottomRadius: CGFloat = 14) {
        self.earRadius = earRadius
        self.bottomRadius = bottomRadius
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let e = max(0, min(earRadius, rect.width / 4))
        let b = max(0, min(bottomRadius, min((rect.width - 2 * e) / 2, rect.height)))
        
        // Leaves top bezel edge unstroked so it seamlessly flows out of the screen's black bezel
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        
        // Top-left concave ear fillet
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + e, y: rect.minY + e),
            control: CGPoint(x: rect.minX + e, y: rect.minY)
        )
        
        // Left vertical edge
        path.addLine(to: CGPoint(x: rect.minX + e, y: rect.maxY - b))
        
        // Bottom-left convex squircle corner
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + e + b, y: rect.maxY),
            control: CGPoint(x: rect.minX + e, y: rect.maxY)
        )
        
        // Bottom horizontal edge
        path.addLine(to: CGPoint(x: rect.maxX - e - b, y: rect.maxY))
        
        // Bottom-right convex squircle corner
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - e, y: rect.maxY - b),
            control: CGPoint(x: rect.maxX - e, y: rect.maxY)
        )
        
        // Right vertical edge
        path.addLine(to: CGPoint(x: rect.maxX - e, y: rect.minY + e))
        
        // Top-right concave ear fillet
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - e, y: rect.minY)
        )
        
        return path
    }
}

public struct DynamicIslandView: View {
    @ObservedObject var state: IslandState
    @State private var isDropTargeted = false
    
    public init(state: IslandState = .shared) {
        self.state = state
    }
    
    // MARK: - Dynamic Adaptive Dimensions (Content-Hugging & Responsive)
    private var islandWidth: CGFloat {
        state.currentDimensions.width
    }
    
    private var islandHeight: CGFloat {
        state.currentDimensions.height
    }
    
    private var bottomRadius: CGFloat {
        if !state.isIslandVisible {
            return 3
        }
        if state.isShowingBatteryHUD || state.isShowingWifiHUD || state.isShowingBluetoothHUD || state.isShowingVolumeHUD {
            return 18 // Soft, spacious continuous squircle corners for HUD
        }
        if state.isShowingCapsLockHUD {
            return 16
        }
        switch state.mode {
        case .compact:
            return 14 // Sleek Apple notch corner radius for compact height
        case .expanded:
            return 24 // Refined G2 squircle curvature
        }
    }
    
    private var earRadius: CGFloat {
        if !state.isIslandVisible {
            return 2
        }
        if state.mode == .expanded {
            return 11 // Authentic Apple concave ear fillets that preserve full content width
        }
        if state.isShowingBatteryHUD || state.isShowingWifiHUD || state.isShowingBluetoothHUD || state.isShowingVolumeHUD {
            return 8
        }
        return 6 // Subtle, organic concave ears in compact mode
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - OLED Jet-Black MacBook Notch (Seamless Bezel Integration & Morphing)
            ZStack(alignment: .top) {
                NotchShape(earRadius: earRadius, bottomRadius: bottomRadius)
                    .fill(Color.black.opacity(state.isIslandVisible ? 1.0 : 0.85))
                    .overlay(
                        NotchOutlineShape(earRadius: earRadius, bottomRadius: bottomRadius)
                            .stroke(
                                isDropTargeted
                                    ? Color.green.opacity(0.85)
                                    : Color.white.opacity(0.14),
                                lineWidth: isDropTargeted ? 1.5 : (state.isIslandVisible ? 0.6 : 0.5)
                            )
                    )
                
                if state.isIslandVisible {
                    if state.isShowingVolumeHUD {
                        volumeHUDContent
                            .transition(.opacity)
                    } else if state.isShowingBatteryHUD {
                        batteryHUDContent
                            .transition(.opacity)
                    } else if state.isShowingWifiHUD {
                        wifiHUDContent
                            .transition(.opacity)
                    } else if state.isShowingBluetoothHUD {
                        bluetoothHUDContent
                            .transition(.opacity)
                    } else if state.isShowingCapsLockHUD {
                        capsLockHUDContent
                            .transition(.opacity)
                    } else {
                        switch state.mode {
                        case .compact:
                            compactContent
                                .transition(.opacity.animation(.easeInOut(duration: 0.18)))
                        case .expanded:
                            expandedContent
                                .transition(.asymmetric(
                                    insertion: .opacity.animation(.easeInOut(duration: 0.20).delay(0.10)),
                                    removal: .opacity.animation(.easeInOut(duration: 0.08))
                                ))
                        }
                    }
                }
            }
            .frame(width: islandWidth, height: islandHeight, alignment: .top)
            .clipShape(NotchShape(earRadius: earRadius, bottomRadius: bottomRadius))
            .contentShape(NotchShape(earRadius: earRadius, bottomRadius: bottomRadius))
            .onTapGesture {
                if !state.isIslandVisible {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.80)) {
                        state.isHoverRevealed = true
                    }
                } else if state.mode == .compact {
                    state.toggleExpand()
                }
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.32, dampingFraction: 0.80), value: state.isIslandVisible)
        .animation(.spring(response: 0.32, dampingFraction: 0.80), value: state.activeTab)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: state.isLyricsEnabled)
        .animation(.easeInOut(duration: 0.18), value: state.isPlaying)
        .animation(.easeInOut(duration: 0.20), value: state.isShowingVolumeHUD)
        .animation(.easeInOut(duration: 0.20), value: state.isShowingBatteryHUD)
        .animation(.easeInOut(duration: 0.20), value: state.isShowingWifiHUD)
        .animation(.easeInOut(duration: 0.20), value: state.isShowingBluetoothHUD)
        .animation(.easeInOut(duration: 0.20), value: state.isShowingCapsLockHUD)
        .animation(.easeInOut(duration: 0.18), value: state.shelfSegment)
        .padding(.top, 0)
        .onDrop(of: ["public.file-url"], isTargeted: $isDropTargeted) { providers in
            handleDroppedFiles(providers)
            return true
        }
        .onChange(of: isDropTargeted) { targeted in
            if targeted && state.mode == .compact {
                state.onModeChangedToExpanded?()
                withAnimation(.easeInOut(duration: 0.22)) {
                    state.activeTab = .shelf
                    state.mode = .expanded
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func handleDroppedFiles(_ providers: [NSItemProvider]) {
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
            if state.mode == .compact {
                state.onModeChangedToExpanded?()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                    state.activeTab = .shelf
                    state.mode = .expanded
                }
            }
        }
    }
    
    // MARK: - iOS Volume & Mute HUD (Hardware keys trigger)
    private var volumeHUDContent: some View {
        HStack(spacing: 12) {
            if state.isMuted {
                Image(systemName: "speaker.slash.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.35))
                    .frame(width: 18)
                
                Text("Muted")
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("Silent")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.35))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.18))
                    .clipShape(Capsule())
            } else {
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
                    .frame(height: geo.size.height, alignment: .center)
                }
                .frame(height: 6)
                
                Text("\(state.currentVolume)%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 36, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .offset(y: 2) // optical vertical center alignment inside top-bezel notch
    }
    
    private var volumeIcon: String {
        if state.isMuted || state.currentVolume == 0 { return "speaker.slash.fill" }
        if state.currentVolume < 33 { return "speaker.wave.1.fill" }
        if state.currentVolume < 66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
    
    // MARK: - iOS 3-Column Pill HUD Notification Component (Matching Reference)
    private func pillHUDNotificationView(
        ringColor: Color,
        ringProgress: Double,
        iconName: String,
        iconColor: Color = .white,
        title: String,
        subtitle: String,
        trailingText: String
    ) -> some View {
        HStack(spacing: 12) {
            // 1. Left: Dynamic Circular Progress Ring with Center Icon
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.14), lineWidth: 2.6)
                
                Circle()
                    .trim(from: 0, to: CGFloat(max(0.04, min(1.0, ringProgress))))
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: iconName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(iconColor)
            }
            .frame(width: 25, height: 25)
            
            // 2. Middle: Title + Subtitle
            VStack(alignment: .leading, spacing: 1.5) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
                    .lineLimit(1)
            }
            
            Spacer(minLength: 6)
            
            // 3. Right: Prominent Percentage or Status
            Text(trailingText)
                .font(.system(size: 17.5, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .offset(y: 2) // optical vertical center alignment for top-bezel notch
    }
    
    // MARK: - iOS MagSafe Battery HUD (Reference Matching 3-Column Pill)
    private var batteryHUDContent: some View {
        let isCharging = state.isBatteryCharging || state.isPowerPlugged
        let ringColor = isCharging ? Color(red: 0.18, green: 0.85, blue: 0.38) : (state.batteryLevel <= 20 ? Color.red : Color(red: 1.0, green: 0.62, blue: 0.10))
        let icon = isCharging ? "bolt.fill" : "powerplug"
        let title = isCharging ? "Charging" : "On Battery"
        let subtitle = isCharging ? "Charger connected" : "Charger disconnected"
        
        return pillHUDNotificationView(
            ringColor: ringColor,
            ringProgress: Double(state.batteryLevel) / 100.0,
            iconName: icon,
            iconColor: .white,
            title: title,
            subtitle: subtitle,
            trailingText: "\(state.batteryLevel)%"
        )
    }
    
    // MARK: - Wi-Fi HUD Notification (Connected vs Disconnected)
    private var wifiHUDContent: some View {
        let isConnected = state.isWifiOn
        let ringColor = isConnected ? Color(red: 0.10, green: 0.55, blue: 1.0) : Color(white: 0.35)
        let icon = isConnected ? "wifi" : "wifi.slash"
        let title = "Wi-Fi"
        let subtitle = isConnected ? (state.wifiSSID.isEmpty ? "Connected" : "Connected • \(state.wifiSSID)") : "Disconnected"
        let trailing = isConnected ? "On" : "Off"
        
        return pillHUDNotificationView(
            ringColor: ringColor,
            ringProgress: 1.0,
            iconName: icon,
            iconColor: isConnected ? .white : Color.white.opacity(0.60),
            title: title,
            subtitle: subtitle,
            trailingText: trailing
        )
    }
    
    // MARK: - Bluetooth & AirPods HUD Notification (Connected vs Disconnected)
    private var bluetoothHUDContent: some View {
        let isConnected = state.isBluetoothOn
        let hasDevice = !state.bluetoothDeviceName.isEmpty
        let isAirPods = state.bluetoothDeviceIcon.contains("airpod") || state.bluetoothDeviceIcon.contains("headphone")
        let ringColor = isConnected ? (isAirPods ? Color(red: 0.20, green: 0.85, blue: 0.40) : Color(red: 0.20, green: 0.60, blue: 1.0)) : Color(white: 0.35)
        let icon = isConnected ? state.bluetoothDeviceIcon : "bluetooth.slash"
        let title = hasDevice ? state.bluetoothDeviceName : "Bluetooth"
        let subtitle = isConnected ? (hasDevice ? "Connected" : "On") : "Disconnected"
        
        let trailing: String
        let progress: Double
        if let batt = state.bluetoothDeviceBattery, batt > 0 {
            trailing = "\(batt)%"
            progress = Double(batt) / 100.0
        } else {
            trailing = isConnected ? "On" : "Off"
            progress = 1.0
        }
        
        return pillHUDNotificationView(
            ringColor: ringColor,
            ringProgress: progress,
            iconName: icon,
            iconColor: isConnected ? .white : Color.white.opacity(0.60),
            title: title,
            subtitle: subtitle,
            trailingText: trailing
        )
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
    
    // MARK: - 1. Compact View (Centered Clock, Timer, & Responsive Media)
    private var compactContent: some View {
        ZStack {
            if state.isTimerRunning {
                HStack(spacing: 5.5) {
                    Image(systemName: "timer")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    
                    Text(state.timerFormattedString)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if state.isPlaying {
                HStack(spacing: 7) {
                    if let art = state.artworkImage {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 17, height: 17)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundColor(.pink)
                    }
                    
                    Text(state.trackTitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    waveformView(height: 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, 10)
            } else {
                // Living Notch Idle State: Animated Spider-Man Mascot Eyes + Digital Clock
                HStack(spacing: 7) {
                    SpiderMascotEyesView(state: state)
                    
                    Text(currentShortTime)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(height: 28, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .top)
    }
    
    // MARK: - 2. Expanded View (iOS Responsive Card)
    private var expandedContent: some View {
        VStack(spacing: 8) {
            // iOS Segmented Tab Bar Header (Responsive & Non-wrapping)
            HStack(spacing: 2) {
                ForEach(IslandTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.80)) {
                            state.activeTab = tab
                        }
                    }) {
                        HStack(spacing: 3) {
                            tabIcon(for: tab)
                            
                            Text(tab.rawValue)
                                .font(.system(size: 10.5, weight: state.activeTab == tab ? .bold : .medium, design: .rounded))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            
                            if let badge = tabBadgeCount(for: tab), badge > 0 {
                                Text("\(badge)")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: true)
                                    .frame(minWidth: 13, minHeight: 13)
                                    .padding(.horizontal, 2)
                                    .background(state.activeTab == tab ? Color.white.opacity(0.32) : Color.white.opacity(0.18))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 5)
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
                
                Spacer(minLength: 2)
                
                // Collapse button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.22)) {
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
            .padding(.top, 14)
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // Tab Contents (Simple Responsive Crossfade)
            Group {
                switch state.activeTab {
                case .control:
                    controlTabView
                case .music:
                    musicTabView
                case .notes:
                    notesTabView
                case .devices:
                    devicesTabView
                case .shelf:
                    shelfTabView
                }
            }
            .transition(.opacity)
            .id(state.activeTab)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                // Mic Mute Tile
                controlTileCompact(
                    icon: state.isMicMuted ? "mic.slash.fill" : "mic.fill",
                    title: "Mic",
                    subtitle: state.isMicMuted ? "Muted" : "Active",
                    isActive: state.isMicMuted,
                    activeColor: Color(red: 1.0, green: 0.35, blue: 0.35)
                ) {
                    state.toggleMicMute()
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
            HStack(spacing: 10) {
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
                                .foregroundColor(state.currentVolume > 12 ? Color.black.opacity(0.75) : Color.white)
                                .padding(.leading, 10)
                            
                            Spacer()
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
                
                Text("\(state.currentVolume)%")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .frame(width: 34, alignment: .trailing)
            }
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
    
    // MARK: - Tab 2: Now Playing (Authentic iOS Dynamic Island Media Player & Apple Music Lyrics)
    private var musicTabView: some View {
        ZStack {
            if state.isLyricsEnabled {
                lyricsSplitView
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeInOut(duration: 0.22).delay(0.08)),
                        removal: .opacity.animation(.easeInOut(duration: 0.16))
                    ))
            } else {
                normalMusicPlayerView
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeInOut(duration: 0.20)),
                        removal: .opacity.animation(.easeInOut(duration: 0.14))
                    ))
            }
        }
    }
    
    // MARK: - Normal Player View (Single-column iOS dynamic island music player)
    private var normalMusicPlayerView: some View {
        VStack(spacing: 10) {
            // Row 1: Artwork, Title/Artist, and Neon Waveform
            HStack(spacing: 12) {
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
                                colors: [Color(red: 0.95, green: 0.25, blue: 0.45), Color(red: 0.48, green: 0.15, blue: 0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "music.note")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.trackTitle)
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(state.artistName)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.68))
                        .lineLimit(1)
                }
                
                Spacer(minLength: 8)
                
                // Animated Waveform Indicator (Pure White)
                waveformView(height: 16)
                    .padding(.trailing, 4)
            }
            .padding(.top, 2)
            
            // Row 2: Interactive Scrubber Bar with Knob & Realtime Seeking
            scrubberBarView()
            
            // Row 3: Playback Controls (Perfect Center) + Secondary Actions (Lyrics & AirPlay on Right)
            ZStack {
                // Centered Main Playback Controls
                HStack(spacing: 32) {
                    Button(action: { state.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { state.togglePlayPause() }) {
                        Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { state.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
                
                // Right Secondary Actions (Spaced & Not Mepet)
                HStack {
                    Spacer()
                    
                    HStack(spacing: 14) {
                        // Apple Music Synchronized Lyrics Toggle Button
                        Button(action: { state.toggleLyrics() }) {
                            Image(systemName: "quote.bubble.fill")
                                .font(.system(size: 14.5, weight: .semibold))
                                .foregroundColor(state.isLyricsEnabled ? Color(red: 1.0, green: 0.22, blue: 0.38) : Color.white.opacity(0.70))
                                .padding(4)
                                .background(
                                    Circle()
                                        .fill(state.isLyricsEnabled ? Color.white.opacity(0.18) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                        
                        // AirPlay / Audio Output Route
                        Button(action: {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.sound") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Image(systemName: "airplayaudio")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white.opacity(0.75))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.trailing, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Apple Music Lyrics Split View (Left: Compact Controls | Right: Synchronized Lyrics)
    private var lyricsSplitView: some View {
        HStack(spacing: 18) {
            // SISI KIRI: Player Column (~340 pt)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ZStack {
                        if let art = state.artworkImage {
                            Image(nsImage: art)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 46, height: 46)
                                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        } else {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [Color(red: 0.95, green: 0.25, blue: 0.45), Color(red: 0.48, green: 0.15, blue: 0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 46, height: 46)
                            
                            Image(systemName: "music.note")
                                .font(.system(size: 19, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 46, height: 46)
                    .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
                    
                    VStack(alignment: .leading, spacing: 2.5) {
                        Text(state.trackTitle)
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(state.artistName)
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.68))
                            .lineLimit(1)
                    }
                    
                    Spacer(minLength: 4)
                }
                
                // Mini Scrubber Bar
                scrubberBarView()
                
                // Controls Row
                HStack(spacing: 16) {
                    Button(action: { state.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { state.togglePlayPause() }) {
                        Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { state.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    // Lyrics Toggle (Active Pink Pill)
                    Button(action: { state.toggleLyrics() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "quote.bubble.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Lyrics")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(red: 1.0, green: 0.22, blue: 0.38))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    // AirPlay / Audio Output Route
                    Button(action: {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.sound") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Image(systemName: "airplayaudio")
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 340)
            
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1)
                .frame(maxHeight: .infinity)
            
            // SISI KANAN: Apple Music Karaoke Scrolling Lyrics (~300 pt)
            lyricsScrollingPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.vertical, 4)
        .clipped()
    }
    
    // MARK: - Apple Music Karaoke Scrolling Lyrics
    private var lyricsScrollingPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            if state.isLoadingLyrics {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.85)
                    Text("Searching lyrics...")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = state.lyricsErrorMessage, state.lyricsLines.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "music.mic")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.40))
                    Text(error)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            Color.clear.frame(height: 25)
                            
                            ForEach(Array(state.lyricsLines.enumerated()), id: \.element.id) { idx, line in
                                let isCurrent = (state.currentLyricIndex == idx)
                                Button(action: {
                                    state.seekTo(line.timestamp)
                                }) {
                                    Text(line.text)
                                        .font(.system(size: isCurrent ? 14.5 : 12.5, weight: isCurrent ? .bold : .medium, design: .rounded))
                                        .foregroundColor(isCurrent ? .white : .white.opacity(0.35))
                                        .shadow(color: Color.white.opacity(isCurrent ? 0.22 : 0.0), radius: 6, x: 0, y: 0)
                                        .scaleEffect(isCurrent ? 1.02 : 1.0, anchor: .leading)
                                        .blur(radius: isCurrent ? 0 : 0.25)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: isCurrent)
                                }
                                .buttonStyle(.plain)
                                .id(idx)
                            }
                            
                            Color.clear.frame(height: 45)
                        }
                        .padding(.horizontal, 6)
                    }
                    .onChange(of: state.currentLyricIndex) { newIdx in
                        if let newIdx = newIdx {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                proxy.scrollTo(newIdx, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Reusable Interactive Scrubber Bar
    private func scrubberBarView() -> some View {
        HStack(spacing: 7) {
            Text(state.currentTime)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white.opacity(0.65))
                .frame(minWidth: 34, alignment: .leading)
            
            GeometryReader { geo in
                let barWidth = geo.size.width
                let progress = max(0, min(1.0, state.playbackProgress))
                let currentWidth = barWidth * CGFloat(progress)
                
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.20))
                        .frame(height: 4.5)
                    
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(0, currentWidth), height: 4.5)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 9, height: 9)
                        .shadow(color: Color.black.opacity(0.4), radius: 2, x: 0, y: 1)
                        .offset(x: max(0, min(barWidth - 9, currentWidth - 4.5)))
                }
                .frame(height: 14)
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let locationX = max(0, min(barWidth, gesture.location.x))
                            let pct = Double(locationX / barWidth)
                            let maxDur = state.totalDurationSeconds > 0 ? state.totalDurationSeconds : 180.0
                            let seekSeconds = pct * maxDur
                            state.seekTo(seekSeconds)
                        }
                )
            }
            .frame(height: 14)
            
            Text(state.remainingTime)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white.opacity(0.65))
                .frame(minWidth: 38, alignment: .trailing)
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Tab 3: Reminders & Notes (iOS Reminders Style)
    private var notesTabView: some View {
        VStack(spacing: 7) {
            // Input field with Dark Elegant Container & Pure White Text
            HStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    if state.newTodoText.isEmpty {
                        Text("Add a reminder or note...")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    
                    TextField("", text: $state.newTodoText, onCommit: {
                        state.addTodo()
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .accentColor(.white)
                    .tint(.white)
                }
                
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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                    .background(Color(red: 0.0, green: 0.48, blue: 1.0))
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .disabled(state.newTodoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(state.newTodoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1.0)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.white.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1.0)
                    )
            )
            
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
            .frame(height: 86)
            
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
    
    // MARK: - Tab 4: Connected Devices & Battery Hub (iOS Concept Style)
    private var devicesTabView: some View {
        VStack(spacing: 11) {
            let isDense = state.connectedDevices.count > 3
            HStack(spacing: isDense ? 8 : 12) {
                ForEach(state.connectedDevices) { dev in
                    DeviceCardView(dev: dev, isDense: isDense)
                }
            }
            .padding(.top, 1)
            
            // Bottom System Power Info Pill
            HStack(spacing: 6) {
                Image(systemName: state.isPowerPlugged ? "bolt.fill" : "battery.100")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(state.isBatteryCharging ? Color(red: 0.18, green: 0.85, blue: 0.38) : Color.white.opacity(0.8))
                
                Text(state.isBatteryCharging ? "Charging via Power Adapter" : (state.isPowerPlugged ? "Connected to Power Adapter" : "Running on Battery Power"))
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                
                Spacer()
                
                Text("Health Normal")
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(red: 0.18, green: 0.85, blue: 0.38))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 0.18, green: 0.85, blue: 0.38).opacity(0.15))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }
    
    // MARK: - Tab 5: File Shelf & Quick Clipboard
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
                        Text("Photos, videos, or Word/PDF docs (Max 10)")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.50))
                    }
                }
                .frame(height: 96)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(state.shelfFiles.enumerated()), id: \.element) { idx, url in
                            shelfFileCard(url: url, index: idx)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }
                .frame(height: 74)
                
                HStack {
                    Text("\(state.shelfFiles.count)/10 files ready to drag out")
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
            handleDroppedFiles(providers)
            return true
        }
    }
    
    private func shelfFileCard(url: URL, index: Int) -> some View {
        let ext = url.pathExtension.lowercased()
        let isImage = ["png", "jpg", "jpeg", "heic", "webp", "gif", "bmp", "tiff"].contains(ext)
        let isVideo = ["mp4", "mov", "m4v", "mkv", "avi", "webm"].contains(ext)
        
        return VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
                        )
                    
                    if isImage, let img = NSImage(contentsOf: url) {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    } else if isVideo {
                        ZStack {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                            
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(3.5)
                                        .background(Color.black.opacity(0.75))
                                        .clipShape(Circle())
                                }
                            }
                            .padding(3)
                        }
                        .frame(width: 48, height: 48)
                    } else {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 34, height: 34)
                    }
                }
                .frame(width: 48, height: 48)
                
                Button(action: { state.removeFile(at: index) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.85))
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .offset(x: 3, y: -3)
            }
            
            Text(url.lastPathComponent)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
                .frame(width: 52)
        }
        .frame(width: 54)
        .contentShape(Rectangle())
        .onDrag { NSItemProvider(contentsOf: url)! }
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
                        Text("Copied texts will automatically appear here (Max 20)")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.50))
                    }
                }
                .frame(height: 96)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4.5) {
                        ForEach(Array(state.clipboardHistory.enumerated()), id: \.offset) { idx, item in
                            let isUrl = item.hasPrefix("http://") || item.hasPrefix("https://")
                            let isCode = item.contains("{") || item.contains("}") || item.contains("func ")
                            let clipIcon = isUrl ? "link" : (isCode ? "chevron.left.forwardslash.chevron.right" : "doc.text")
                            let iconColor = isUrl ? Color(red: 0.20, green: 0.60, blue: 1.0) : (isCode ? Color.orange : Color.white.opacity(0.50))
                            
                            Button(action: {
                                state.copyClip(at: idx)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: state.copiedClipIndex == idx ? "checkmark.circle.fill" : clipIcon)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(state.copiedClipIndex == idx ? Color.green : iconColor)
                                    
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
                    Text("\(state.clipboardHistory.count)/20 items in history")
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
        case .devices:
            return Image(systemName: "battery.100.bolt").font(.system(size: 9.5, weight: .bold, design: .rounded))
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
                    .fill(Color.white)
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

// MARK: - Authentic Spider-Man Mascot Eyes View (Living Notch Mascot)
public struct SpiderMascotEyesView: View {
    @ObservedObject var state: IslandState
    
    @State private var isBlinking: Bool = false
    @State private var lookOffsetX: CGFloat = 0
    @State private var lookOffsetY: CGFloat = 0
    
    // Timer for organic natural camera-aperture shutter blinking (every 3.6s)
    private let blinkTimer = Timer.publish(every: 3.6, on: .main, in: .common).autoconnect()
    // Timer for organic glances (every 4.8s)
    private let glanceTimer = Timer.publish(every: 4.8, on: .main, in: .common).autoconnect()
    
    public init(state: IslandState = .shared) {
        self.state = state
    }
    
    public var body: some View {
        HStack(spacing: 3.0) {
            if let leftImg = SpiderEyesAssets.leftImage {
                Image(nsImage: leftImg)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 13, height: 17)
                    .scaleEffect(
                        y: isBlinking ? 0.12 : (state.isHoverRevealed ? 0.62 : 1.0),
                        anchor: .center
                    )
                    .scaleEffect(
                        x: state.isHoverRevealed ? 0.95 : 1.0,
                        anchor: .center
                    )
            }
            
            if let rightImg = SpiderEyesAssets.rightImage {
                Image(nsImage: rightImg)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 13, height: 17)
                    .scaleEffect(
                        y: isBlinking ? 0.12 : (state.isHoverRevealed ? 0.62 : 1.0),
                        anchor: .center
                    )
                    .scaleEffect(
                        x: state.isHoverRevealed ? 0.95 : 1.0,
                        anchor: .center
                    )
            }
        }
        .offset(x: lookOffsetX, y: lookOffsetY)
        .animation(.spring(response: 0.18, dampingFraction: 0.72), value: isBlinking)
        .animation(.spring(response: 0.32, dampingFraction: 0.75), value: state.isHoverRevealed)
        .animation(.spring(response: 0.38, dampingFraction: 0.70), value: lookOffsetX)
        .onReceive(blinkTimer) { _ in
            triggerBlink()
        }
        .onReceive(glanceTimer) { _ in
            triggerGlance()
        }
    }
    
    private func triggerBlink() {
        guard !state.isHoverRevealed else { return }
        withAnimation(.easeIn(duration: 0.08)) {
            isBlinking = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.16, dampingFraction: 0.75)) {
                isBlinking = false
            }
        }
    }
    
    private func triggerGlance() {
        guard !state.isHoverRevealed else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                lookOffsetX = 0
                lookOffsetY = 0
            }
            return
        }
        let offsets: [CGFloat] = [0, -2.0, 2.0, 0, -1.5, 1.5, 0]
        let chosen = offsets.randomElement() ?? 0
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            lookOffsetX = chosen
        }
    }
}

// Backward compatibility alias
public typealias MascotEyesView = SpiderMascotEyesView

private struct DeviceCardView: View {
    let dev: ConnectedDevice
    let isDense: Bool
    
    private var progressValue: CGFloat {
        if dev.batteryLevel > 0 {
            return CGFloat(dev.batteryLevel) / 100.0
        }
        return 1.0
    }
    
    private var ringColor: Color {
        if dev.isCharging {
            return Color(red: 0.18, green: 0.85, blue: 0.38)
        }
        if dev.batteryLevel > 20 || dev.batteryLevel <= 0 {
            return Color(red: 0.18, green: 0.85, blue: 0.38)
        }
        return Color(red: 1.0, green: 0.23, blue: 0.19)
    }
    
    private var batteryText: String {
        if dev.isConnected {
            return dev.batteryLevel > 0 ? "\(dev.batteryLevel)%" : "On"
        }
        return "Off"
    }
    
    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(dev.isConnected ? 0.12 : 0.06), lineWidth: isDense ? 3.8 : 4.5)
                
                if dev.isConnected {
                    Circle()
                        .trim(from: 0, to: progressValue)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: isDense ? 3.8 : 4.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                
                VStack(spacing: 1) {
                    Image(systemName: dev.iconName)
                        .font(.system(size: isDense ? 14 : 16, weight: .semibold))
                        .foregroundColor(dev.isConnected ? .white : .white.opacity(0.35))
                    
                    if dev.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundColor(Color(red: 0.18, green: 0.85, blue: 0.38))
                    }
                }
            }
            .frame(width: isDense ? 46 : 52, height: isDense ? 46 : 52)
            
            Text(batteryText)
                .font(.system(size: isDense ? 11.5 : 13, weight: .bold, design: .rounded))
                .foregroundColor(dev.isConnected ? .white : .white.opacity(0.40))
            
            Text(dev.name)
                .font(.system(size: isDense ? 9 : 10, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(dev.isConnected ? 0.85 : 0.45))
                .lineLimit(1)
            
            Text(dev.subtitle)
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(dev.isConnected ? 0.50 : 0.28))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(Color.white.opacity(dev.isConnected ? 0.06 : 0.03))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}
