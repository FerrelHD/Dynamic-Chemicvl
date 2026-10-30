import SwiftUI
import AppKit
import ImageIO

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
        
        // Top-left concave ear fillet (Silky Smooth Circular Tangent Fillet)
        path.addCurve(
            to: CGPoint(x: rect.minX + e, y: rect.minY + e),
            control1: CGPoint(x: rect.minX + e * 0.5523, y: rect.minY),
            control2: CGPoint(x: rect.minX + e, y: rect.minY + e * 0.4477)
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
        
        // Top-right concave ear fillet (Silky Smooth Circular Tangent Fillet)
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control1: CGPoint(x: rect.maxX - e, y: rect.minY + e * 0.4477),
            control2: CGPoint(x: rect.maxX - e * 0.5523, y: rect.minY)
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
        
        // Top-left concave ear fillet (Silky Smooth Circular Tangent Fillet)
        path.addCurve(
            to: CGPoint(x: rect.minX + e, y: rect.minY + e),
            control1: CGPoint(x: rect.minX + e * 0.5523, y: rect.minY),
            control2: CGPoint(x: rect.minX + e, y: rect.minY + e * 0.4477)
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
        
        // Top-right concave ear fillet (Silky Smooth Circular Tangent Fillet)
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control1: CGPoint(x: rect.maxX - e, y: rect.minY + e * 0.4477),
            control2: CGPoint(x: rect.maxX - e * 0.5523, y: rect.minY)
        )
        
        return path
    }
}

public struct DynamicIslandView: View {
    @ObservedObject var state: IslandState
    @State private var isDropTargeted = false
    @State private var isGenieClearing = false
    @State private var isClearShelfButtonPulsing = false
    @State private var isTrashLidOpenShelf = false
    @State private var isGenieClearingClipboard = false
    @State private var isClearClipboardButtonPulsing = false
    @State private var isTrashLidOpenClipboard = false
    @State private var isScrubbingAudio = false
    @State private var localScrubProgress: Double = 0.0
    @State private var airPodsSpinAngle: Double = 0.0
    @State private var hoveredTrashId: UUID? = nil
    @State private var lastUserLyricScroll: Date = Date.distantPast
    @State private var lyricScrollMonitor: Any? = nil
    @State private var isHoveringLyrics: Bool = false
    
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
    
    private var isTallBanner: Bool {
        state.isTallNotificationActive
    }
    
    private var bottomRadius: CGFloat {
        if state.isShowingBatteryHUD || state.isShowingWifiHUD || state.isShowingBluetoothHUD || state.isShowingVolumeHUD {
            return 16
        }
        if state.isShowingCapsLockHUD {
            return 14
        }
        if isTallBanner {
            return 22 // Curvature matching reference notification banners
        }
        switch state.mode {
        case .compact:
            return 14 // Sleek Apple notch corner radius for compact height
        case .expanded:
            return 24 // Refined G2 squircle curvature
        }
    }
    
    private var earRadius: CGFloat {
        if isTallBanner {
            return 13
        }
        if state.mode == .expanded {
            return 15 // Silky smooth Apple G2 concave ear fillets
        }
        if state.isShowingBatteryHUD || state.isShowingWifiHUD || state.isShowingBluetoothHUD || state.isShowingVolumeHUD {
            return 11
        }
        return 9 // Sleek, organic concave ears in compact mode
    }
    
    // MARK: - Dynamic Ambient Artwork Glow View (KeyNotch 3-Point Lighting)
    private var ambientGlowView: some View {
        let dominant = state.artworkDominantColor ?? Color(red: 0.16, green: 0.10, blue: 0.28)
        return ZStack(alignment: .bottom) {
            // 1. Point 1: Full-width vertical ambient wash (Top 38% pure jet-black OLED, zero bleed to camera/menubar)
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.38),
                    .init(color: dominant.opacity(0.18), location: 0.55),
                    .init(color: dominant.opacity(0.50), location: 0.78),
                    .init(color: dominant.opacity(0.80), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // 2. Point 2: Bottom-trailing corner radial anchor (KeyNotch lighting, confined to bottom corners)
            RadialGradient(
                colors: [
                    dominant.opacity(0.85),
                    dominant.opacity(0.38),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 15,
                endRadius: 185
            )
            
            // 3. Point 3: Bottom-leading corner radial anchor (KeyNotch lighting, confined to bottom corners)
            RadialGradient(
                colors: [
                    dominant.opacity(0.75),
                    dominant.opacity(0.32),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 165
            )
        }
        .allowsHitTesting(false)
    }
    
    public var body: some View {
        let isAmbientGlowVisible = state.isIslandVisible 
            && state.mode == .expanded 
            && state.activeTab == .music 
            && state.activeCallNotification == nil
            && state.activeChatNotification == nil
            && state.activeAirDropNotification == nil
            && !state.isTallNotificationActive
        
        VStack(spacing: 0) {
            // MARK: - OLED Jet-Black MacBook Notch (Seamless Bezel Integration & Morphing)
            ZStack(alignment: .top) {
                NotchShape(earRadius: earRadius, bottomRadius: bottomRadius)
                    .fill(Color.black)
                    .overlay(
                        ambientGlowView
                            .opacity(isAmbientGlowVisible ? 1.0 : 0.0)
                            .clipShape(NotchShape(earRadius: earRadius, bottomRadius: bottomRadius))
                    )
                    .overlay(
                        NotchOutlineShape(earRadius: earRadius, bottomRadius: bottomRadius)
                            .stroke(
                                isDropTargeted
                                    ? Color.green.opacity(0.85)
                                    : Color.white.opacity(0.14),
                                lineWidth: isDropTargeted ? 1.5 : 0.6
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
                    } else if let chat = state.activeChatNotification {
                        chatNotificationContent(chat: chat)
                            .transition(.opacity)
                    } else if let call = state.activeCallNotification {
                        if state.mode == .compact, case .active(let dur) = call.state {
                            compactCallContent(call: call, duration: dur)
                                .transition(.opacity)
                        } else {
                            callNotificationContent(call: call)
                                .transition(.opacity)
                        }
                    } else if let airdrop = state.activeAirDropNotification, case .completed = airdrop.phase {
                        airDropCompleteContent(airdrop: airdrop)
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
            .scaleEffect(y: state.isIslandVisible ? 1.0 : 0.45, anchor: .top)
            .opacity(state.isIslandVisible ? 1.0 : 0.0)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(state.animationStyle.springAnimation, value: state.isIslandVisible)
        .animation(state.animationStyle.springAnimation, value: state.activeTab)
        .animation(state.animationStyle.springAnimation, value: state.isLyricsEnabled)
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
            state.triggerHaptic(.alignment)
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
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 38, alignment: .trailing)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
        trailingText: String,
        is3DSpinning: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            // 1. Left: Dynamic Circular Progress Ring with Center Icon
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.14), lineWidth: 2.8)
                
                Circle()
                    .trim(from: 0, to: CGFloat(max(0.04, min(1.0, ringProgress))))
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: iconName)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(iconColor)
                    .rotation3DEffect(.degrees(is3DSpinning ? airPodsSpinAngle : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
            }
            .frame(width: 28, height: 28)
            
            // 2. Middle: Title + Subtitle
            VStack(alignment: .leading, spacing: 2) {
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
                .font(.system(size: 16.5, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
        let isAirPods = state.bluetoothDeviceIcon.contains("airpod") || state.bluetoothDeviceName.lowercased().contains("airpod") || state.bluetoothDeviceName.lowercased().contains("bud")
        let ringColor = isConnected ? (isAirPods ? Color(red: 0.18, green: 0.85, blue: 0.38) : Color(red: 0.20, green: 0.60, blue: 1.0)) : Color(white: 0.35)
        let icon = isConnected ? (isAirPods ? "airpodspro" : state.bluetoothDeviceIcon) : "antenna.radiowaves.left.and.right.slash"
        let title = hasDevice ? state.bluetoothDeviceName : "Bluetooth"
        let subtitle = isConnected ? (hasDevice ? "Connected" : "On") : "Disconnected"
        
        let trailing: String
        let progress: Double
        if let batt = state.bluetoothDeviceBattery, batt > 0 {
            trailing = "\(batt)%"
            progress = Double(batt) / 100.0
        } else {
            trailing = isConnected ? (isAirPods ? "100%" : "On") : "Off"
            progress = 1.0
        }
        
        return pillHUDNotificationView(
            ringColor: ringColor,
            ringProgress: progress,
            iconName: icon,
            iconColor: isConnected ? .white : Color.white.opacity(0.60),
            title: title,
            subtitle: subtitle,
            trailingText: trailing,
            is3DSpinning: isAirPods
        )
        .onAppear {
            if isAirPods {
                airPodsSpinAngle = 0.0
                withAnimation(.spring(response: 0.85, dampingFraction: 0.72)) {
                    airPodsSpinAngle = 360.0
                }
            }
        }
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
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    // MARK: - Chat Notification Content (Matching Dynamic Island Reference)
    private func chatNotificationContent(chat: ChatNotification) -> some View {
        Button(action: {
            openChatApp(chat)
            state.dismissChatNotification()
        }) {
            HStack(spacing: 12) {
                // 1. Sender Avatar or Real App Icon with App Badge
                ZStack(alignment: .bottomTrailing) {
                    if let avatar = chat.avatarImage {
                        Image(nsImage: avatar)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else if let appIcon = chat.app.appIcon {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        Circle()
                            .fill(chat.app.badgeColor.opacity(0.85))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(String(chat.sender.prefix(1)))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            )
                    }
                    
                    // App Badge (WhatsApp, Telegram, etc.) - Only overlay when displaying a real contact photo, omitted for WhatsApp chat
                    if chat.isCustomAvatar && chat.app != .whatsapp {
                        ZStack {
                            Circle()
                                .fill(chat.app.badgeColor)
                                .frame(width: 16, height: 16)
                            Image(systemName: chat.app.iconName)
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 3, y: 3)
                    }
                }
                .frame(width: 42, height: 42)
                
                // 2. Sender Name, Time Tag & 2-Line Text Preview
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(chat.sender)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(chat.timestamp)
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.50))
                    }
                    
                    Text(chat.message)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                        .lineSpacing(1.5)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Compact Active Call Pill (Pure Apple Dynamic Island)
    private func compactCallContent(call: CallNotification, duration: Int) -> some View {
        ZStack {
            HStack {
                Image(systemName: "phone.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 0.20, green: 0.85, blue: 0.40))
                
                Spacer()
                
                waveformView(height: 10)
            }
            
            Text(state.formatCallDuration(duration))
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture {
            state.toggleExpand()
        }
    }
    
    // MARK: - Incoming & Active Call Notification Content
    private func callNotificationContent(call: CallNotification) -> some View {
        HStack(spacing: 12) {
            // 1. Caller Avatar
            if let avatar = call.avatarImage {
                Image(nsImage: avatar)
                    .interpolation(.high)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 38, height: 38)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(white: 0.22))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Text(String(call.callerName.prefix(1)))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    )
            }
            
            // 2. Subtitle & Caller Name
            VStack(alignment: .leading, spacing: 1.5) {
                switch call.state {
                case .incoming:
                    Text(call.subtitle)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.60))
                        .lineLimit(1)
                case .active(let dur):
                    HStack(spacing: 4.5) {
                        Text(state.formatCallDuration(dur))
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(Color(red: 0.20, green: 0.85, blue: 0.40))
                        
                        Text("•")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.white.opacity(0.35))
                        
                        Text(call.callType)
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.60))
                            .lineLimit(1)
                    }
                }
                
                Text(call.callerName)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 8)
            
            // 3. Circular Action Buttons
            switch call.state {
            case .incoming:
                HStack(spacing: 12) {
                    // Decline Call (Red)
                    Button(action: { state.declineCall() }) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.95, green: 0.22, blue: 0.22))
                                .frame(width: 32, height: 32)
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // Accept Call (Green)
                    Button(action: { state.acceptCall() }) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.20, green: 0.82, blue: 0.40))
                                .frame(width: 32, height: 32)
                            Image(systemName: "phone.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
            case .active:
                HStack(spacing: 12) {
                    waveformView(height: 14)
                    
                    // End Call (Red)
                    Button(action: { state.endCall() }) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.95, green: 0.22, blue: 0.22))
                                .frame(width: 32, height: 32)
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .offset(y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            if case .active = call.state {
                state.minimize()
            }
        }
    }
    
    // MARK: - AirDrop Complete Notification Card
    private func airDropCompleteContent(airdrop: AirDropNotification) -> some View {
        let fileName: String = {
            if case .completed(let f, _) = airdrop.phase { return f }
            return "Item"
        }()
        let fileURL: URL? = {
            if case .completed(_, let u) = airdrop.phase { return u }
            return nil
        }()
        
        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color(red: 0.15, green: 0.70, blue: 0.35))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(String(airdrop.senderName.prefix(1)))
                                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        )
                    
                    Image(systemName: "wave.3.forward.circle.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
                        .background(Color.black.clipShape(Circle()))
                        .offset(x: 2, y: 2)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("AirDrop Complete")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Received \(fileName) from AirDrop")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.70))
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button(action: { state.dismissAirDrop() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.40))
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            
            HStack(spacing: 8) {
                Button(action: {
                    if let url = fileURL {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } else {
                        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
                        NSWorkspace.shared.open(downloads)
                    }
                    state.dismissAirDrop()
                }) {
                    Text("Show in Finder")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    if let url = fileURL {
                        NSWorkspace.shared.open(url)
                    }
                    state.dismissAirDrop()
                }) {
                    Text("Open")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.0, green: 0.48, blue: 1.0))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .offset(y: 2)
    }
    
    private func openChatApp(_ chat: ChatNotification) {
        let bundleId = chat.customBundleIdentifier ?? chat.app.bundleIdentifier
        if !bundleId.isEmpty, let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }
    
    // MARK: - 1. Compact View (Centered Clock, Timer, & Responsive Media)
    private var compactContent: some View {
        ZStack {
            if let airdrop = state.activeAirDropNotification, case .transferring(let progress) = airdrop.phase {
                HStack(spacing: 8) {
                    Image(systemName: "wave.3.forward.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
                    
                    Text("AirDrop \(Int(progress * 100))%")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 2.2)
                        Circle()
                            .trim(from: 0, to: CGFloat(progress))
                            .stroke(Color(red: 0.0, green: 0.48, blue: 1.0), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 13, height: 13)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, 14)
            } else if state.isTimerRunning {
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
                HStack(spacing: 8) {
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
                .padding(.horizontal, 14)
            } else {
                // Living Notch Idle State: Animated Notchy Cyber Mascot Eyes + Digital Clock
                HStack(spacing: 8) {
                    NotchyMascotEyesView(state: state)
                    
                    Text(currentShortTime)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, 12)
            }
        }
        .frame(height: 28, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .top)
    }
    
    // MARK: - 2. Expanded View (Apple Minimal Card with Uniform Tab Crossfade & Pinned Page Dots)
    private var tabTransition: AnyTransition {
        switch state.tabTransitionDirection {
        case .forward:
            return .asymmetric(
                insertion: .offset(x: 22).combined(with: .opacity).combined(with: .scale(scale: 0.97, anchor: .trailing)),
                removal: .offset(x: -22).combined(with: .opacity).combined(with: .scale(scale: 0.97, anchor: .leading))
            )
        case .backward:
            return .asymmetric(
                insertion: .offset(x: -22).combined(with: .opacity).combined(with: .scale(scale: 0.97, anchor: .leading)),
                removal: .offset(x: 22).combined(with: .opacity).combined(with: .scale(scale: 0.97, anchor: .trailing))
            )
        case .none:
            return .opacity
        }
    }
    
    private var expandedContent: some View {
        ZStack(alignment: .top) {
            // Tab Contents (Spacious Content-first presentation, pinned securely to top)
            Group {
                switch state.activeTab {
                case .control:
                    controlTabView
                case .music:
                    musicTabView
                case .timer:
                    timerTabView
                case .notes:
                    notesTabView
                case .devices:
                    devicesTabView
                case .shelf:
                    shelfTabView
                }
            }
            .transition(tabTransition)
            .id(state.activeTab.rawValue)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 32) // Standardized 32pt horizontal margin for generous breathing room across all tabs
            .padding(.top, (state.activeTab == .music && state.isLyricsEnabled) ? 22 : 14)
            .padding(.bottom, 36)
            
            // Minimal Apple-Style Page Dots & Settings (••• ⚙️) Pinned Permanently at Bottom
            pageDotsBar
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 18) // Exact anchor from Control tab across all tabs
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
    }
    
    // MARK: - Apple-Style Minimal Page Dots Indicator
    private var pageDotsBar: some View {
        HStack(spacing: 6) {
            ForEach(Array(IslandTab.allCases.enumerated()), id: \.element) { index, tab in
                let isCurrent = (state.activeTab == tab)
                Button(action: {
                    state.switchToTab(tab)
                }) {
                    Capsule()
                        .fill(isCurrent ? Color.white : Color.white.opacity(0.40))
                        .frame(width: isCurrent ? 14 : 5, height: 5)
                        .shadow(color: isCurrent ? Color.white.opacity(0.35) : Color.clear, radius: 2)
                        .animation(state.animationStyle.springAnimation, value: isCurrent)
                        .frame(width: isCurrent ? 20 : 16, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            
            // Subtle Dot Separator
            Circle()
                .fill(Color.white.opacity(0.20))
                .frame(width: 2.5, height: 2.5)
                .padding(.horizontal, 2)
            
            // Settings Icon Button (Opens Dedicated Settings Window)
            Button(action: {
                SettingsWindowManager.shared.showSettings()
                state.triggerHaptic(.generic)
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.40))
                    .frame(width: 14, height: 14)
                    .frame(width: 20, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(height: 18)
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
                    icon: "antenna.radiowaves.left.and.right",
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
                        insertion: .opacity.animation(.easeInOut(duration: 0.18)),
                        removal: .opacity.animation(.easeInOut(duration: 0.14))
                    ))
            } else {
                normalMusicPlayerView
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeInOut(duration: 0.18)),
                        removal: .opacity.animation(.easeInOut(duration: 0.14))
                    ))
            }
        }
    }
    
    // MARK: - Normal Player View (Single-column iOS dynamic island music player)
    private var normalMusicPlayerView: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            
            // Row 1: Artwork, Title/Artist, and Neon Waveform
            HStack(spacing: 12) {
                ZStack {
                    if let art = state.artworkImage {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 58, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color(red: 0.95, green: 0.25, blue: 0.45), Color(red: 0.48, green: 0.15, blue: 0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 58, height: 58)
                        
                        Image(systemName: "music.note")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 58, height: 58)
                .scaleEffect(state.isPlaying ? 1.0 : 0.88)
                .shadow(
                    color: Color.black.opacity(state.isPlaying ? 0.45 : 0.20),
                    radius: state.isPlaying ? 8 : 3,
                    x: 0,
                    y: state.isPlaying ? 4 : 2
                )
                .animation(.spring(response: 0.40, dampingFraction: 0.70), value: state.isPlaying)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.trackTitle)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(state.artistName)
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.68))
                        .lineLimit(1)
                }
                
                Spacer(minLength: 8)
                
                // Animated Waveform Indicator (Pure White)
                waveformView(height: 16)
            }
            .padding(.top, 2)
            
            // Row 2: Interactive Scrubber Bar with Knob & Realtime Seeking
            scrubberBarView()
            
            // Row 3: Symmetrical Playback Controls (AirPlay Left, Playback Center, Lyrics Right)
            HStack {
                // Left: AirPlay / Audio Output Route
                Button(action: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.sound") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Image(systemName: "airplayaudio")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(5)
                }
                .buttonStyle(BouncyButtonStyle())
                .frame(width: 32, alignment: .leading)
                
                Spacer()
                
                // Center: Main Playback Controls
                HStack(spacing: 30) {
                    Button(action: { state.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(BouncyButtonStyle())
                    
                    Button(action: { state.togglePlayPause() }) {
                        Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(BouncyButtonStyle())
                    
                    Button(action: { state.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(BouncyButtonStyle())
                }
                
                Spacer()
                
                // Right: Apple Music Synchronized Lyrics Toggle Button
                Button(action: { state.toggleLyrics() }) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundColor(state.isLyricsEnabled ? Color.white : Color.white.opacity(0.60))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(BouncyButtonStyle())
                .frame(width: 32, alignment: .trailing)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - Apple Music Lyrics Split View (Left: Compact Controls | Right: Synchronized Lyrics)
    private var lyricsSplitView: some View {
        HStack(spacing: 24) {
            // SISI KIRI: Player Column (~255 pt, vertically centered)
            VStack(alignment: .leading, spacing: 10) {
                Spacer(minLength: 0)
                HStack(spacing: 11) {
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
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(state.artistName)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.68))
                            .lineLimit(1)
                    }
                    
                    Spacer(minLength: 4)
                }
                
                // Mini Scrubber Bar
                scrubberBarView()
                
                // Symmetrical Controls (AirPlay Left, Playback Center, Lyrics Right - Opsi B)
                HStack {
                    // Left: AirPlay / Audio Output Route
                    Button(action: {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.sound") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Image(systemName: "airplayaudio")
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundColor(.white.opacity(0.75))
                            .padding(4)
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .frame(width: 28, alignment: .leading)
                    
                    Spacer()
                    
                    // Center: Playback Controls
                    HStack(spacing: 20) {
                        Button(action: { state.previousTrack() }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(BouncyButtonStyle())
                        
                        Button(action: { state.togglePlayPause() }) {
                            Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(BouncyButtonStyle())
                        
                        Button(action: { state.nextTrack() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(BouncyButtonStyle())
                    }
                    
                    Spacer()
                    
                    // Right: Apple Music Synchronized Lyrics Toggle Button (Icon-only Opsi B)
                    Button(action: { state.toggleLyrics() }) {
                        Image(systemName: "quote.bubble.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.white)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .frame(width: 28, alignment: .trailing)
                }
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity)
                
                Spacer(minLength: 0)
            }
            .frame(width: 250)
            .frame(maxHeight: .infinity)
            
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1)
                .frame(maxHeight: .infinity)
            
            // SISI KANAN: Apple Music Karaoke Scrolling Lyrics (~410 pt)
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
                lyricsLoadingView
            } else if let error = state.lyricsErrorMessage, state.lyricsLines.isEmpty {
                lyricsErrorView(message: error)
            } else {
                lyricsListScrollView
            }
        }
    }
    
    private var lyricsLoadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.85)
            Text("Searching lyrics...")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func lyricsErrorView(message: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "music.mic")
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.40))
            Text(message)
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var lyricsListScrollView: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        // Dynamic top space agar baris pertama bisa berada di anchor 0.38
                        Color.clear.frame(height: max(20, geo.size.height * 0.38))
                        
                        ForEach(state.lyricsLines.indices, id: \.self) { idx in
                            lyricRowButton(line: state.lyricsLines[idx], idx: idx, proxy: proxy)
                        }
                        
                        // Dynamic bottom space agar baris terakhir bisa berada di anchor 0.38
                        Color.clear.frame(height: max(40, geo.size.height * 0.62))
                    }
                    .padding(.horizontal, 6)
                }
                .onHover { hovering in
                    isHoveringLyrics = hovering
                }
                .onAppear {
                    scrollToActiveLyric(proxy: proxy, animated: false)
                    
                    if let m = lyricScrollMonitor { NSEvent.removeMonitor(m) }
                    lyricScrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                        if isHoveringLyrics {
                            lastUserLyricScroll = Date()
                        }
                        return event
                    }
                }
                .onDisappear {
                    if let m = lyricScrollMonitor { NSEvent.removeMonitor(m) }
                    lyricScrollMonitor = nil
                }
                .onChange(of: state.currentLyricIndex) { newIdx in
                    guard let newIdx = newIdx,
                          Date().timeIntervalSince(lastUserLyricScroll) > 3.0 else { return }
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                        proxy.scrollTo(newIdx, anchor: UnitPoint(x: 0.5, y: 0.38))
                    }
                }
                .onChange(of: state.isLoadingLyrics) { loading in
                    if !loading {
                        scrollToActiveLyric(proxy: proxy, animated: true)
                    }
                }
                .onChange(of: state.isLyricsEnabled) { enabled in
                    if enabled {
                        scrollToActiveLyric(proxy: proxy, animated: true)
                    }
                }
            }
        }
    }
    
    private func scrollToActiveLyric(proxy: ScrollViewProxy, animated: Bool) {
        guard let idx = state.currentLyricIndex, state.lyricsLines.indices.contains(idx) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            if animated {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                    proxy.scrollTo(idx, anchor: UnitPoint(x: 0.5, y: 0.38))
                }
            } else {
                proxy.scrollTo(idx, anchor: UnitPoint(x: 0.5, y: 0.38))
            }
        }
    }
    
    private func lyricRowButton(line: LyricLine, idx: Int, proxy: ScrollViewProxy) -> some View {
        let active = state.currentLyricIndex
        let isCurrent = (active == idx)
        let distance = active.map { abs($0 - idx) } ?? 4
        let blur: CGFloat = isCurrent ? 0 : min(CGFloat(distance), 4) * 0.7
        
        return Button(action: {
            lastUserLyricScroll = .distantPast // Reset manual scroll timer so it jumps immediately
            state.seekTo(line.timestamp)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                proxy.scrollTo(idx, anchor: UnitPoint(x: 0.5, y: 0.38))
            }
        }) {
            Text(line.text)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .opacity(isCurrent ? 1.0 : 0.38)
                .blur(radius: blur)
                .scaleEffect(isCurrent ? 1.0 : 0.92, anchor: .leading)
                .animation(.spring(response: 0.45, dampingFraction: 0.8), value: isCurrent)
        }
        .buttonStyle(.plain)
        .id(idx)
    }
    
    // MARK: - Apple Music Mini Player Scrubber Bar (Thumbless, Thick Capsule with Spring Expansion)
    private func scrubberBarView() -> some View {
        let displayProgress = isScrubbingAudio ? localScrubProgress : max(0, min(1.0, state.playbackProgress))
        let maxDur = (state.totalDurationSeconds.isFinite && !state.totalDurationSeconds.isNaN && state.totalDurationSeconds > 0) ? state.totalDurationSeconds : 180.0
        let displayCurrentTime: String = {
            if isScrubbingAudio {
                let currentSecs = displayProgress * maxDur
                return state.formatTime(state.safeSeconds(currentSecs))
            } else {
                return state.currentTime
            }
        }()
        let displayRemainingTime: String = {
            if isScrubbingAudio {
                let remSecs = max(0, maxDur - (displayProgress * maxDur))
                return "-\(state.formatTime(state.safeSeconds(remSecs)))"
            } else {
                return state.remainingTime
            }
        }()
        
        return HStack(spacing: 8) {
            Text(displayCurrentTime)
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white.opacity(0.65))
                .frame(minWidth: 34, alignment: .leading)
            
            GeometryReader { geo in
                let barWidth = geo.size.width
                let currentWidth = barWidth * CGFloat(displayProgress)
                
                ZStack(alignment: .leading) {
                    // Track background (20% white opacity)
                    Capsule()
                        .fill(Color.white.opacity(0.20))
                    
                    // Progress fill (70% white opacity, clipped to track)
                    Capsule()
                        .fill(Color.white.opacity(0.70))
                        .frame(width: max(0, currentWidth))
                }
                .clipShape(Capsule())
                .frame(height: isScrubbingAudio ? 9.5 : 5.5)
                .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isScrubbingAudio)
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            if !isScrubbingAudio {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                                    isScrubbingAudio = true
                                }
                            }
                            let locationX = max(0, min(barWidth, gesture.location.x))
                            let pct = max(0.0, min(1.0, Double(locationX / barWidth)))
                            localScrubProgress = pct
                        }
                        .onEnded { gesture in
                            let locationX = max(0, min(barWidth, gesture.location.x))
                            let pct = max(0.0, min(1.0, Double(locationX / barWidth)))
                            let seekSeconds = pct * maxDur
                            state.seekTo(seekSeconds)
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                                isScrubbingAudio = false
                            }
                        }
                )
            }
            .frame(height: 24)
            
            Text(displayRemainingTime)
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white.opacity(0.65))
                .frame(minWidth: 38, alignment: .trailing)
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Tab: Dedicated Timer (Horizontal Ruler Dial, OLED True Black)
    private var timerTabView: some View {
        VStack(spacing: 14) {
            // Upper: Horizontal Draggable Ruler Dial
            RulerDialView(
                selectedMinutes: Binding(
                    get: { state.timerSelectedMinutes },
                    set: { state.setTimerMinutes($0) }
                ),
                isEnabled: !state.isTimerRunning
            )
            .padding(.top, 4)
            
            Spacer(minLength: 4)
            
            // Lower: Controls & Big Digital Display
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Button(action: { state.toggleTimer() }) {
                        HStack(spacing: 5) {
                            Image(systemName: state.isTimerRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 10.5, weight: .bold))
                            Text(state.isTimerRunning ? "Pause" : "Start Timer")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.orange)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    if state.isTimerRunning || state.timerRemainingSeconds != (state.timerSelectedMinutes * 60) {
                        Button(action: { state.resetTimer() }) {
                            Text("Reset")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.75))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                // Big OLED True Black Digital Readout (e.g. 49:00)
                Text(state.timerFormattedString)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
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
                            // Full-width clickable toggle area (Checkmark icon + Text + Spacer)
                            Button(action: { state.toggleTodo(id: todo.id) }) {
                                HStack(spacing: 8) {
                                    Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 14.5, weight: .bold, design: .rounded))
                                        .foregroundColor(todo.isDone ? Color(red: 0.0, green: 0.48, blue: 1.0) : Color.white.opacity(0.50))
                                        .frame(width: 26, height: 26)
                                    
                                    Text(todo.text)
                                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                        .foregroundColor(todo.isDone ? .white.opacity(0.45) : .white)
                                        .strikethrough(todo.isDone, color: .white.opacity(0.45))
                                        .lineLimit(1)
                                    
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            // Dedicated Trash Button with 30x30 hit target and active hover pill
                            Button(action: { state.deleteTodo(id: todo.id) }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(hoveredTrashId == todo.id ? Color.red : Color.white.opacity(0.45))
                                    .frame(width: 30, height: 30)
                                    .background(
                                        Circle()
                                            .fill(hoveredTrashId == todo.id ? Color.red.opacity(0.20) : Color.white.opacity(0.001))
                                    )
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .onHover { isHovered in
                                hoveredTrashId = isHovered ? todo.id : nil
                            }
                        }
                        .padding(.leading, 8)
                        .padding(.trailing, 4)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            .frame(height: 86)
            
            Divider()
                .background(Color.white.opacity(0.10))
                .padding(.vertical, 2)
            
            // Footer Info
            HStack {
                let remaining = state.todos.filter { !$0.isDone }.count
                Text("\(remaining) task\(remaining == 1 ? "" : "s") remaining")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.60))
                
                Spacer()
                
                if state.todos.contains(where: { $0.isDone }) {
                    Button(action: { state.clearCompletedTodos() }) {
                        Text("Clear Completed")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(Color.orange)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 2)
            .padding(.bottom, 4)
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
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .padding(.bottom, 6)
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
                            let cardCenterX = 27.0 + CGFloat(idx) * 64.0
                            let targetX = 320.0 - cardCenterX
                            shelfFileCard(url: url, index: idx)
                                .scaleEffect(
                                    x: isGenieClearing ? 0.04 : 1.0,
                                    y: isGenieClearing ? 0.02 : 1.0,
                                    anchor: .bottomTrailing
                                )
                                .rotationEffect(.degrees(isGenieClearing ? Double(14 - (idx % 3) * 6) : 0))
                                .offset(
                                    x: isGenieClearing ? targetX : 0,
                                    y: isGenieClearing ? 55 : 0
                                )
                                .opacity(isGenieClearing ? 0.0 : 1.0)
                                .animation(
                                    .easeInOut(duration: 0.30).delay(Double(idx) * 0.035),
                                    value: isGenieClearing
                                )
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
                    Button(action: { triggerGenieClearShelf() }) {
                        HStack(spacing: 5) {
                            TrashCanIconView(isOpen: isTrashLidOpenShelf, color: .red)
                            Text("Clear All")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.red)
                        .scaleEffect(isClearShelfButtonPulsing ? 1.12 : 1.0)
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
    
    private func triggerGenieClearShelf() {
        guard !isGenieClearing, !state.shelfFiles.isEmpty else { return }
        
        // Phase 1: Lid pops open
        withAnimation(.spring(response: 0.22, dampingFraction: 0.62)) {
            isTrashLidOpenShelf = true
            isClearShelfButtonPulsing = true
        }
        
        // Phase 2: Card suction into trash mouth
        withAnimation(.easeInOut(duration: 0.32).delay(0.04)) {
            isGenieClearing = true
        }
        
        let totalDelay = 0.36 + Double(min(state.shelfFiles.count, 6)) * 0.035
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
            state.clearShelf()
            isGenieClearing = false
            // Phase 3: Lid snaps shut with spring bounce
            withAnimation(.spring(response: 0.24, dampingFraction: 0.58)) {
                isTrashLidOpenShelf = false
                isClearShelfButtonPulsing = false
            }
        }
    }
    
    private func shelfFileCard(url: URL, index: Int) -> some View {
        let ext = url.pathExtension.lowercased()
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
                    
                    // Asynchronously cached 48x48 thumbnail (zero Main Thread lag)
                    ShelfThumbnailItemView(url: url)
                    
                    if isVideo {
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
                    
                    // Native AppKit file drag session (100% reliable drop into Finder, Desktop, Mail, etc.)
                    NativeDraggableArea(url: url)
                }
                .frame(width: 48, height: 48)
                
                Button(action: { state.removeFile(at: index) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.85))
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                        .frame(width: 18, height: 18)
                        .contentShape(Circle())
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
    }
    
    private var clipboardEmptyView: some View {
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
    }
    
    private func clipboardItemRow(item: String, idx: Int) -> some View {
        let isUrl = item.hasPrefix("http://") || item.hasPrefix("https://")
        let isCode = item.contains("{") || item.contains("}") || item.contains("func ")
        let clipIcon = isUrl ? "link" : (isCode ? "chevron.left.forwardslash.chevron.right" : "doc.text")
        let iconColor = isUrl ? Color(red: 0.20, green: 0.60, blue: 1.0) : (isCode ? Color.orange : Color.white.opacity(0.50))
        let isCopied = state.copiedClipIndex == idx
        
        return Button(action: {
            state.copyClip(at: idx)
        }) {
            HStack(spacing: 8) {
                Image(systemName: isCopied ? "checkmark.circle.fill" : clipIcon)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(isCopied ? Color.green : iconColor)
                
                Text(item.replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                Text(isCopied ? "Copied!" : "Copy")
                    .font(.system(size: 9, weight: isCopied ? .bold : .semibold, design: .rounded))
                    .foregroundColor(isCopied ? Color.green : .white.opacity(0.40))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.white.opacity(isCopied ? 0.18 : 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .scaleEffect(
            x: isGenieClearingClipboard ? 0.04 : 1.0,
            y: isGenieClearingClipboard ? 0.02 : 1.0,
            anchor: .bottomTrailing
        )
        .offset(
            x: isGenieClearingClipboard ? 165 : 0,
            y: isGenieClearingClipboard ? CGFloat(50 + (6 - min(idx, 6)) * 6) : 0
        )
        .opacity(isGenieClearingClipboard ? 0.0 : 1.0)
        .animation(
            .easeInOut(duration: 0.26).delay(Double(min(idx, 6)) * 0.025),
            value: isGenieClearingClipboard
        )
    }
    
    private var clipboardHistoryContent: some View {
        VStack(spacing: 7) {
            if state.clipboardHistory.isEmpty {
                clipboardEmptyView
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4.5) {
                        ForEach(Array(state.clipboardHistory.enumerated()), id: \.offset) { idx, item in
                            clipboardItemRow(item: item, idx: idx)
                        }
                    }
                }
                .frame(height: 72)
                
                HStack {
                    Text("\(state.clipboardHistory.count)/20 items in history")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.60))
                    Spacer()
                    Button(action: { triggerGenieClearClipboard() }) {
                        HStack(spacing: 5) {
                            TrashCanIconView(isOpen: isTrashLidOpenClipboard, color: .red)
                            Text("Clear All")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.red)
                        .scaleEffect(isClearClipboardButtonPulsing ? 1.12 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func triggerGenieClearClipboard() {
        guard !isGenieClearingClipboard, !state.clipboardHistory.isEmpty else { return }
        
        // Phase 1: Lid pops open
        withAnimation(.spring(response: 0.22, dampingFraction: 0.62)) {
            isTrashLidOpenClipboard = true
            isClearClipboardButtonPulsing = true
        }
        
        // Phase 2: Suction into trash mouth
        withAnimation(.easeInOut(duration: 0.28).delay(0.04)) {
            isGenieClearingClipboard = true
        }
        
        let totalDelay = 0.32 + Double(min(state.clipboardHistory.count, 6)) * 0.025
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
            state.clearClipboard()
            isGenieClearingClipboard = false
            // Phase 3: Lid snaps shut with spring bounce
            withAnimation(.spring(response: 0.24, dampingFraction: 0.58)) {
                isTrashLidOpenClipboard = false
                isClearClipboardButtonPulsing = false
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
        case .timer:
            return Image(systemName: "timer").font(.system(size: 9.5, weight: .bold, design: .rounded))
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
                RoundedRectangle(cornerRadius: 1.2)
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 2.2, height: max(3.5, height * state.waveHeights[idx]))
                    .shadow(color: Color.white.opacity(0.20), radius: 1, x: 0, y: 0)
            }
        }
    }
    
    private var currentShortTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}


private struct DeviceCardView: View {
    let dev: ConnectedDevice
    let isDense: Bool
    @State private var spinAngle: Double = 0.0
    
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
                        .rotation3DEffect(.degrees(spinAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
                    
                    if dev.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundColor(Color(red: 0.18, green: 0.85, blue: 0.38))
                    }
                }
            }
            .frame(width: isDense ? 46 : 52, height: isDense ? 46 : 52)
            .contentShape(Circle())
            .onAppear {
                if dev.iconName.contains("airpod") && dev.isConnected {
                    spinAngle = 0.0
                    withAnimation(.spring(response: 0.85, dampingFraction: 0.72)) {
                        spinAngle = 360.0
                    }
                }
            }
            .onTapGesture {
                if dev.iconName.contains("airpod") {
                    spinAngle = 0.0
                    IslandState.shared.triggerHaptic(.alignment)
                    withAnimation(.spring(response: 0.85, dampingFraction: 0.72)) {
                        spinAngle = 360.0
                    }
                }
            }
            
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

// MARK: - Authentic Animated 2-Piece Apple Trash Can Component
public struct TrashCanIconView: View {
    let isOpen: Bool
    var color: Color = .red
    
    public var body: some View {
        VStack(spacing: 0.8) {
            // Lid with handle
            ZStack(alignment: .bottom) {
                // Top handle
                Capsule()
                    .fill(color)
                    .frame(width: 4.2, height: 1.3)
                    .offset(y: -2.0)
                
                // Lid rim
                RoundedRectangle(cornerRadius: 0.8, style: .continuous)
                    .fill(color)
                    .frame(width: 11.5, height: 1.8)
            }
            .rotationEffect(.degrees(isOpen ? -34 : 0), anchor: .bottomLeading)
            .offset(x: isOpen ? -1.4 : 0, y: isOpen ? -2.8 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isOpen)
            
            // Can Body
            TrashCanBodyShape()
                .fill(color)
                .frame(width: 9.5, height: 9.2)
                .overlay(
                    // Inner ribs
                    HStack(spacing: 2.2) {
                        Capsule().fill(Color.black.opacity(0.35)).frame(width: 1, height: 5.5)
                        Capsule().fill(Color.black.opacity(0.35)).frame(width: 1, height: 5.5)
                    }
                )
        }
        .frame(width: 14, height: 14, alignment: .bottom)
    }
}

struct TrashCanBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let topInset: CGFloat = 0.5
        let bottomInset: CGFloat = 1.2
        path.move(to: CGPoint(x: rect.minX + topInset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topInset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - bottomInset, y: rect.maxY - 1.5))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottomInset - 1.5, y: rect.maxY),
            control: CGPoint(x: rect.maxX - bottomInset, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + bottomInset + 1.5, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + bottomInset, y: rect.maxY - 1.5),
            control: CGPoint(x: rect.minX + bottomInset, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - OLED Horizontal Ruler Dial Component (Calibrated 1:1 Precision Dial)
public struct RulerDialView: View {
    @Binding var selectedMinutes: Int
    var isEnabled: Bool = true
    
    private let tickSpacing: CGFloat = 16.0
    private let minMinutes: Int = 5
    private let maxMinutes: Int = 120
    
    @State private var isDragging: Bool = false
    @State private var dragTranslation: CGFloat = 0
    @State private var dragStartMinute: Int = 25
    
    public init(selectedMinutes: Binding<Int>, isEnabled: Bool = true) {
        self._selectedMinutes = selectedMinutes
        self.isEnabled = isEnabled
    }
    
    public var body: some View {
        GeometryReader { geo in
            let baseMinute = isDragging ? dragStartMinute : selectedMinutes
            let activeOffset = isDragging ? dragTranslation : 0
            let middleIndex = CGFloat(maxMinutes - minMinutes) / 2.0
            let currentOffset = -(CGFloat(baseMinute - minMinutes) - middleIndex) * tickSpacing + activeOffset
            
            ZStack(alignment: .bottom) {
                // Ticks track
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(minMinutes...maxMinutes, id: \.self) { min in
                        let isMajor = (min % 5 == 0)
                        let isSelected = (min == selectedMinutes)
                        
                        VStack(spacing: 3) {
                            if isMajor {
                                Text("\(min)m")
                                    .font(.system(size: 10, weight: isSelected ? .bold : .semibold, design: .rounded))
                                    .foregroundColor(isSelected ? .orange : .white.opacity(0.42))
                                    .frame(width: 36, height: 14)
                            } else {
                                Spacer().frame(height: 14)
                            }
                            
                            Rectangle()
                                .fill(isSelected ? Color.orange : (isMajor ? Color.white.opacity(0.60) : Color.white.opacity(0.18)))
                                .frame(width: isSelected ? 2.0 : (isMajor ? 1.5 : 1.0), height: isSelected ? 18 : (isMajor ? 14 : 7))
                        }
                        .frame(width: tickSpacing, height: 42, alignment: .bottom)
                    }
                }
                .offset(x: currentOffset)
                
                // Orange Center Triangle Indicator ▲
                Image(systemName: "triangle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.orange)
                    .offset(y: 11)
            }
            .frame(width: geo.size.width, height: 48, alignment: .bottom)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { val in
                        guard isEnabled else { return }
                        if !isDragging {
                            isDragging = true
                            dragStartMinute = selectedMinutes
                        }
                        dragTranslation = val.translation.width
                        let deltaMins = Int(round(-dragTranslation / tickSpacing))
                        let candidate = dragStartMinute + deltaMins
                        let clamped = max(minMinutes, min(maxMinutes, candidate))
                        if selectedMinutes != clamped {
                            selectedMinutes = clamped
                            IslandState.shared.triggerHaptic(.alignment)
                        }
                    }
                    .onEnded { _ in
                        guard isEnabled else { return }
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.72)) {
                            dragTranslation = 0
                            isDragging = false
                        }
                    }
            )
        }
        .frame(height: 52)
    }
}

// MARK: - Native AppKit Drag-Out Component for File Shelf
public final class NativeFileDragView: NSView, NSDraggingSource {
    public var fileURL: URL?
    private var dragStartLocation: NSPoint?
    
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    public override func mouseDown(with event: NSEvent) {
        dragStartLocation = event.locationInWindow
    }
    
    public override func mouseDragged(with event: NSEvent) {
        guard let url = fileURL, let startLoc = dragStartLocation else { return }
        let currentLoc = event.locationInWindow
        let dist = hypot(currentLoc.x - startLoc.x, currentLoc.y - startLoc.y)
        guard dist > 4.0 else { return }
        dragStartLocation = nil
        
        let dragItem = NSDraggingItem(pasteboardWriter: url as NSURL)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 48, height: 48)
        let dragRect = NSRect(x: self.bounds.midX - 24, y: self.bounds.midY - 24, width: 48, height: 48)
        dragItem.setDraggingFrame(dragRect, contents: icon)
        
        self.beginDraggingSession(with: [dragItem], event: event, source: self)
    }
    
    public func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return context == .outsideApplication ? [.copy, .generic] : .copy
    }
}

public struct NativeDraggableArea: NSViewRepresentable {
    public let url: URL
    
    public init(url: URL) {
        self.url = url
    }
    
    public func makeNSView(context: Context) -> NativeFileDragView {
        let view = NativeFileDragView()
        view.fileURL = url
        return view
    }
    
    public func updateNSView(_ nsView: NativeFileDragView, context: Context) {
        nsView.fileURL = url
    }
}

// MARK: - Shelf Asynchronous 48x48 Thumbnail Cache
public final class ShelfThumbnailCache {
    public static let shared = ShelfThumbnailCache()
    private let cache = NSCache<NSURL, NSImage>()
    
    private init() {
        cache.countLimit = 60
    }
    
    public func thumbnail(for url: URL) -> NSImage? {
        return cache.object(forKey: url as NSURL)
    }
    
    public func loadThumbnail(for url: URL, completion: @escaping (NSImage) -> Void) {
        if let cached = cache.object(forKey: url as NSURL) {
            completion(cached)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let ext = url.pathExtension.lowercased()
            let isImage = ["png", "jpg", "jpeg", "heic", "webp", "gif", "bmp", "tiff"].contains(ext)
            
            var generated: NSImage?
            if isImage {
                if let source = CGImageSourceCreateWithURL(url as CFURL, nil) {
                    let options: [CFString: Any] = [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceShouldCacheImmediately: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: 96
                    ]
                    if let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                        generated = NSImage(cgImage: cgThumb, size: NSSize(width: 48, height: 48))
                    }
                }
            }
            
            if generated == nil {
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 48, height: 48)
                generated = icon
            }
            
            if let finalImg = generated {
                self?.cache.setObject(finalImg, forKey: url as NSURL)
                DispatchQueue.main.async {
                    completion(finalImg)
                }
            }
        }
    }
}

public struct ShelfThumbnailItemView: View {
    public let url: URL
    @State private var thumbImage: NSImage?
    
    public init(url: URL) {
        self.url = url
    }
    
    public var body: some View {
        Group {
            if let img = thumbImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 48, height: 48)
            }
        }
        .onAppear {
            if let cached = ShelfThumbnailCache.shared.thumbnail(for: url) {
                thumbImage = cached
            } else {
                ShelfThumbnailCache.shared.loadThumbnail(for: url) { img in
                    self.thumbImage = img
                }
            }
        }
    }
}

// MARK: - Tactile Bouncy Button Style (Spring Press Feedback)
public struct BouncyButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .opacity(configuration.isPressed ? 0.75 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}
