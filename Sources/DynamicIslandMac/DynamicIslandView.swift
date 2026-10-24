import SwiftUI
import AppKit

public struct DynamicIslandView: View {
    @ObservedObject var state: IslandState
    @State private var isDropTargeted = false
    
    public init(state: IslandState = .shared) {
        self.state = state
    }
    
    // Dynamic dimensions (iOS Floating Pill & Card)
    private var islandWidth: CGFloat {
        if state.isShowingVolumeHUD {
            return 250
        }
        switch state.mode {
        case .compact:
            return state.isPlaying ? 205 : (state.isTimerRunning ? 180 : 160)
        case .expanded:
            return 395
        }
    }
    
    private var islandHeight: CGFloat {
        if state.isShowingVolumeHUD {
            return 36
        }
        switch state.mode {
        case .compact:
            return 34
        case .expanded:
            return 215
        }
    }
    
    private var cornerRadius: CGFloat {
        if state.isShowingVolumeHUD {
            return 18
        }
        switch state.mode {
        case .compact:
            return islandHeight / 2 // Perfect squircle pill
        case .expanded:
            return 28 // iOS continuous card curvature
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
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
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.76), value: state.mode)
            .animation(.spring(response: 0.28, dampingFraction: 0.80), value: state.isShowingVolumeHUD)
            .animation(.easeInOut(duration: 0.18), value: state.activeTab)
            
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
    
    // MARK: - 1. Compact View (Centered Clock & Media Pill)
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
                }
            } else if state.isPlaying {
                HStack(spacing: 8) {
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
                // Centered Clock & Icon
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                    
                    Text(currentShortTime)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
    }
    
    // MARK: - 2. Expanded View (iOS Card)
    private var expandedContent: some View {
        VStack(spacing: 10) {
            // iOS Segmented Tab Bar Header
            HStack(spacing: 4) {
                ForEach(IslandTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            state.activeTab = tab
                        }
                    }) {
                        HStack(spacing: 5) {
                            tabIcon(for: tab)
                            Text(tabLabel(for: tab))
                                .font(.system(size: 11, weight: state.activeTab == tab ? .bold : .medium, design: .rounded))
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 9)
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
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                        .padding(6)
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
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }
    
    // MARK: - Tab 1: Control Center (iOS Style Tiles)
    private var controlTabView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
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
            
            HStack(spacing: 10) {
                // Focus / DND Tile
                controlTile(
                    icon: "moon.fill",
                    title: "Focus",
                    subtitle: state.isDNDOn ? "Do Not Disturb" : "Off",
                    isActive: state.isDNDOn,
                    activeColor: Color(red: 0.35, green: 0.34, blue: 0.84)
                ) {
                    state.toggleDND()
                }
                
                // Focus Timer Tile
                controlTile(
                    icon: "timer",
                    title: "Focus Timer",
                    subtitle: state.isTimerRunning ? state.timerFormattedString : "25 min",
                    isActive: state.isTimerRunning,
                    activeColor: Color(red: 1.0, green: 0.58, blue: 0.0)
                ) {
                    state.toggleTimer()
                }
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
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isActive ? activeColor : Color.white.opacity(0.18))
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
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
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.09))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.75)
            )
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Tab 2: Now Playing (iOS Live Activity Style)
    private var musicTabView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    if let art = state.artworkImage {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 46, height: 46)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color(red: 0.95, green: 0.2, blue: 0.45), Color(red: 0.5, green: 0.1, blue: 0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 46, height: 46)
                        
                        Image(systemName: "music.note")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 46, height: 46)
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
                
                waveformView(height: 20)
            }
            
            // Progress Bar & Timestamps
            VStack(spacing: 3) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(Color.white)
                            .frame(width: max(0, geo.size.width * CGFloat(state.playbackProgress)), height: 4)
                    }
                }
                .frame(height: 4)
                
                HStack {
                    Text(state.currentTime)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                    
                    Spacer()
                    
                    Text(state.totalDuration)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                }
            }
            
            // iOS Media Controls
            HStack(spacing: 28) {
                Button(action: { state.previousTrack() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
                
                // Prominent Play/Pause Button
                Button(action: { state.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                    }
                }
                .buttonStyle(.plain)
                
                Button(action: { state.nextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                HStack(spacing: 5) {
                    Image(systemName: volumeIcon)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                    Text("\(state.currentVolume)%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.10))
                .clipShape(Capsule())
            }
        }
    }
    
    // MARK: - Tab 3: Reminders & Notes (iOS Reminders Style)
    private var notesTabView: some View {
        VStack(spacing: 8) {
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
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        Text("Add")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
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
                VStack(spacing: 5) {
                    ForEach(state.todos) { todo in
                        HStack(spacing: 8) {
                            Button(action: { state.toggleTodo(id: todo.id) }) {
                                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(todo.isDone ? Color.blue : Color.white.opacity(0.45))
                            }
                            .buttonStyle(.plain)
                            
                            Text(todo.text)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(todo.isDone ? .white.opacity(0.45) : .white)
                                .strikethrough(todo.isDone, color: .white.opacity(0.45))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Button(action: { state.deleteTodo(id: todo.id) }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.40))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            .frame(height: 80)
            
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
        }
    }
    
    // MARK: - Tab 4: File Shelf View (Drop Zone)
    private var shelfTabView: some View {
        VStack(spacing: 8) {
            if state.shelfFiles.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [5]))
                        .fill(isDropTargeted ? Color.green : Color.white.opacity(0.25))
                    
                    VStack(spacing: 4) {
                        Image(systemName: "tray.and.arrow.down")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.70))
                        Text("Drop files here for quick shelf")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                        Text("Drag out to any app or email anytime")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.50))
                    }
                }
                .frame(height: 82)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(state.shelfFiles.enumerated()), id: \.element) { idx, url in
                            HStack(spacing: 6) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                    .resizable()
                                    .frame(width: 22, height: 22)
                                
                                Text(url.lastPathComponent)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Button(action: { state.removeFile(at: idx) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .onDrag { NSItemProvider(contentsOf: url)! }
                        }
                    }
                }
                .frame(height: 52)
                
                HStack {
                    Text("\(state.shelfFiles.count) file\(state.shelfFiles.count == 1 ? "" : "s") ready to drag out")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                    Spacer()
                    Button(action: { state.clearShelf() }) {
                        Text("Clear All")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
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
    
    // MARK: - Helpers
    private func tabIcon(for tab: IslandTab) -> some View {
        switch tab {
        case .control:
            return Image(systemName: "slider.horizontal.3").font(.system(size: 10, weight: .bold, design: .rounded))
        case .music:
            return Image(systemName: "music.note").font(.system(size: 10, weight: .bold, design: .rounded))
        case .notes:
            return Image(systemName: "checklist").font(.system(size: 10, weight: .bold, design: .rounded))
        case .shelf:
            return Image(systemName: "tray.fill").font(.system(size: 10, weight: .bold, design: .rounded))
        }
    }
    
    private func tabLabel(for tab: IslandTab) -> String {
        if tab == .shelf && !state.shelfFiles.isEmpty {
            return "\(tab.rawValue) (\(state.shelfFiles.count))"
        }
        if tab == .notes {
            let activeCount = state.todos.filter { !$0.isDone }.count
            return activeCount > 0 ? "\(tab.rawValue) (\(activeCount))" : tab.rawValue
        }
        return tab.rawValue
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
