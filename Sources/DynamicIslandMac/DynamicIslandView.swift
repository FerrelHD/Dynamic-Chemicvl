import SwiftUI
import AppKit

// MARK: - MacBook Hardware Notch Cutout Shape with Concave Ears (Flush with Top Bezel)
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
        path.addArc(
            center: CGPoint(x: rect.minX, y: rect.minY + e),
            radius: e,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + e, y: rect.maxY - b))
        path.addArc(
            center: CGPoint(x: rect.minX + e + b, y: rect.maxY - b),
            radius: b,
            startAngle: .degrees(180),
            endAngle: .degrees(90),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: rect.maxX - e - b, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.maxX - e - b, y: rect.maxY - b),
            radius: b,
            startAngle: .degrees(90),
            endAngle: .degrees(0),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: rect.maxX - e, y: rect.minY + e))
        path.addArc(
            center: CGPoint(x: rect.maxX, y: rect.minY + e),
            radius: e,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
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
        path.addArc(
            center: CGPoint(x: rect.minX, y: rect.minY + e),
            radius: e,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + e, y: rect.maxY - b))
        path.addArc(
            center: CGPoint(x: rect.minX + e + b, y: rect.maxY - b),
            radius: b,
            startAngle: .degrees(180),
            endAngle: .degrees(90),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: rect.maxX - e - b, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.maxX - e - b, y: rect.maxY - b),
            radius: b,
            startAngle: .degrees(90),
            endAngle: .degrees(0),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: rect.maxX - e, y: rect.minY + e))
        path.addArc(
            center: CGPoint(x: rect.maxX, y: rect.minY + e),
            radius: e,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
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
        if state.isShowingVolumeHUD {
            return 260
        }
        if state.isShowingBatteryHUD {
            return 192 // Option 2: Super Compact 192pt
        }
        if state.isShowingCapsLockHUD {
            return 195
        }
        switch state.mode {
        case .compact:
            if state.isTimerRunning {
                return 170
            } else if state.isPlaying {
                // Responsively adapt width to track title length (min 180, max 230)
                let titleLen = CGFloat(state.trackTitle.count)
                return max(180, min(230, 150 + titleLen * 3.0))
            } else {
                return 136 // Sleek, perfectly proportioned Apple compact notch
            }
        case .expanded:
            return 395 // Balanced proportion on 13" and larger screens
        }
    }
    
    private var islandHeight: CGFloat {
        if state.isShowingBatteryHUD {
            return 34 // Option 2: Exact same height as compact notch (no downward bulge)
        }
        if state.isShowingVolumeHUD || state.isShowingCapsLockHUD {
            return 36
        }
        switch state.mode {
        case .compact:
            if state.isTimerRunning || state.isPlaying {
                return 30
            }
            return 28 // Sleek, flush with macOS menu bar height + subtle curve
        case .expanded:
            // Dynamic content-aware height: generous breathing room and no clipping
            switch state.activeTab {
            case .music:
                return 196
            case .control:
                return 232
            case .notes:
                return 216
            case .devices:
                return 236
            case .shelf:
                return 200
            }
        }
    }
    
    private var bottomRadius: CGFloat {
        if state.isShowingBatteryHUD {
            return 14
        }
        if state.isShowingVolumeHUD || state.isShowingCapsLockHUD {
            return 16
        }
        switch state.mode {
        case .compact:
            return 14 // Sleek Apple notch corner radius for 34pt height
        case .expanded:
            return 22 // iOS continuous squircle curvature
        }
    }
    
    private var earRadius: CGFloat {
        return 6 // Elegant, subtle, identical authentic concave fillet in all modes
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            if state.isIslandVisible {
                // MARK: - OLED Jet-Black MacBook Notch (Flush with Top Bezel)
                ZStack(alignment: .top) {
                    NotchShape(earRadius: earRadius, bottomRadius: bottomRadius)
                        .fill(Color.black)
                        .overlay(
                            NotchOutlineShape(earRadius: earRadius, bottomRadius: bottomRadius)
                                .stroke(isDropTargeted ? Color.green.opacity(0.8) : Color.white.opacity(0.12), lineWidth: isDropTargeted ? 1.5 : 0.8)
                        )
                    
                    Group {
                        if state.isShowingVolumeHUD {
                            volumeHUDContent
                                .transition(.opacity)
                        } else if state.isShowingBatteryHUD {
                            batteryHUDContent
                                .transition(.opacity)
                        } else if state.isShowingCapsLockHUD {
                            capsLockHUDContent
                                .transition(.opacity)
                        } else {
                            switch state.mode {
                            case .compact:
                                compactContent
                                    .transition(.asymmetric(
                                        insertion: .opacity.animation(.easeInOut(duration: 0.16).delay(0.06)),
                                        removal: .opacity.animation(.easeInOut(duration: 0.08))
                                    ))
                            case .expanded:
                                expandedContent
                                    .transition(.asymmetric(
                                        insertion: .opacity.animation(.easeInOut(duration: 0.16).delay(0.04)),
                                        removal: .opacity.animation(.easeInOut(duration: 0.08))
                                    ))
                            }
                        }
                    }
                }
                .frame(width: islandWidth, height: islandHeight, alignment: .top)
                .contentShape(NotchShape(earRadius: earRadius, bottomRadius: bottomRadius))
                .onTapGesture {
                    state.toggleExpand()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            } else {
                // MARK: - Tucked Handle (Micro-Notch Flush with Top Bezel)
                NotchShape(earRadius: 2, bottomRadius: 3)
                    .fill(Color.black.opacity(0.85))
                    .overlay(
                        NotchOutlineShape(earRadius: 2, bottomRadius: 3)
                            .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                    )
                    .frame(width: 48, height: 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                            state.isHoverRevealed = true
                        }
                    }
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: state.isIslandVisible)
        .animation(.spring(response: 0.34, dampingFraction: 0.78), value: state.mode)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: state.activeTab)
        .animation(.spring(response: 0.30, dampingFraction: 0.76), value: state.isPlaying)
        .animation(.spring(response: 0.28, dampingFraction: 0.80), value: state.isShowingVolumeHUD)
        .animation(.spring(response: 0.28, dampingFraction: 0.80), value: state.isShowingBatteryHUD)
        .animation(.spring(response: 0.28, dampingFraction: 0.80), value: state.isShowingCapsLockHUD)
        .animation(.spring(response: 0.28, dampingFraction: 0.80), value: state.shelfSegment)
        .padding(.top, 0)
        .onDrop(of: ["public.file-url"], isTargeted: $isDropTargeted) { providers in
            handleDroppedFiles(providers)
            return true
        }
        .onChange(of: isDropTargeted) { targeted in
            if targeted && state.mode == .compact {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                    state.activeTab = .shelf
                    state.mode = .expanded
                }
            }
        }
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
                withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                    state.activeTab = .shelf
                    state.mode = .expanded
                }
            }
        }
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
                .frame(height: geo.size.height, alignment: .center)
            }
            .frame(height: 6)
            
            Text("\(state.currentVolume)%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .offset(y: 2) // optical vertical center alignment inside top-bezel notch
    }
    
    private var volumeIcon: String {
        if state.currentVolume == 0 { return "speaker.slash.fill" }
        if state.currentVolume < 33 { return "speaker.wave.1.fill" }
        if state.currentVolume < 66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
    
    // MARK: - iOS MagSafe Battery HUD Live Activity (Option 2: Super Compact 192x34)
    private var batteryHUDContent: some View {
        HStack(spacing: 7) {
            if state.isBatteryCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 0.18, green: 0.85, blue: 0.38))
                
                Text("Charging • \(state.batteryLevel)%")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            } else if state.isPowerPlugged {
                Image(systemName: "powerplug.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 0.18, green: 0.85, blue: 0.38))
                
                Text("Connected • \(state.batteryLevel)%")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            } else {
                Image(systemName: "battery.75")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(state.batteryLevel <= 20 ? Color.red : Color.orange)
                
                Text("On Battery • \(state.batteryLevel)%")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 2. Expanded View (iOS Responsive Card)
    private var expandedContent: some View {
        VStack(spacing: 8) {
            // iOS Segmented Tab Bar Header (Responsive & Non-wrapping)
            HStack(spacing: 2) {
                ForEach(IslandTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
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
            .padding(.top, 14)
            
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
            case .devices:
                devicesTabView
            case .shelf:
                shelfTabView
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
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
    
    // MARK: - Tab 2: Now Playing (Authentic iOS Dynamic Island Media Player)
    private var musicTabView: some View {
        VStack(spacing: 12) {
            // Row 1: Artwork, Title/Artist, and Neon Waveform
            HStack(spacing: 12) {
                ZStack {
                    if let art = state.artworkImage {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color(red: 0.95, green: 0.25, blue: 0.45), Color(red: 0.48, green: 0.15, blue: 0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "music.note")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 50, height: 50)
                .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 2)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.trackTitle)
                        .font(.system(size: 14.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(state.artistName)
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.68))
                        .lineLimit(1)
                }
                
                Spacer(minLength: 8)
                
                // Animated Waveform Indicator
                waveformView(height: 19)
            }
            .padding(.top, 2)
            
            // Row 2: Single-Row Scrubber Bar with Elapsed & Countdown Remaining
            HStack(spacing: 8) {
                Text(state.currentTime)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.65))
                    .frame(minWidth: 32, alignment: .leading)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.20))
                            .frame(height: 5)
                        
                        Capsule()
                            .fill(Color.white)
                            .frame(width: max(0, geo.size.width * CGFloat(state.playbackProgress)), height: 5)
                    }
                    .frame(height: 5)
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                .frame(height: 14)
                
                Text(state.remainingTime)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.65))
                    .frame(minWidth: 36, alignment: .trailing)
            }
            
            // Row 3: Playback Controls (Centered Flat White + AirPlay on Right)
            HStack(spacing: 0) {
                Spacer()
                
                HStack(spacing: 36) {
                    Button(action: { state.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { state.togglePlayPause() }) {
                        Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { state.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // AirPlay / Audio Output Route
                Button(action: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.sound") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Image(systemName: "airplayaudio")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
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
            // Three Circular Battery Gauges Side-by-Side
            HStack(spacing: 12) {
                ForEach(state.connectedDevices) { dev in
                    VStack(spacing: 5) {
                        ZStack {
                            // Background ring
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 4.5)
                            
                            // Progress ring
                            Circle()
                                .trim(from: 0, to: CGFloat(dev.batteryLevel) / 100.0)
                                .stroke(
                                    dev.isCharging
                                        ? Color(red: 0.18, green: 0.85, blue: 0.38)
                                        : (dev.batteryLevel > 20
                                            ? Color(red: 0.18, green: 0.85, blue: 0.38)
                                            : Color(red: 1.0, green: 0.23, blue: 0.19)),
                                    style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                            
                            // Center Icon
                            VStack(spacing: 1) {
                                Image(systemName: dev.iconName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                if dev.isCharging {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(Color(red: 0.18, green: 0.85, blue: 0.38))
                                }
                            }
                        }
                        .frame(width: 52, height: 52)
                        
                        // Percentage & Device Info
                        Text("\(dev.batteryLevel)%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(dev.name)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                        
                        Text(dev.subtitle)
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.50))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
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
            handleDroppedFiles(providers)
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
