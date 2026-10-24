import SwiftUI
import AppKit

public struct DynamicIslandView: View {
    @ObservedObject var state: IslandState
    @State private var isDropTargeted = false
    
    public init(state: IslandState = .shared) {
        self.state = state
    }
    
    // Dimensi dinamis (Floating Pill)
    private var islandWidth: CGFloat {
        if state.isShowingVolumeHUD {
            return 250
        }
        if state.isDodging {
            return 110 // Menyusut ramping saat menghindar
        }
        switch state.mode {
        case .compact:
            return state.isPlaying ? 200 : (state.isTimerRunning ? 180 : 155)
        case .expanded:
            return 390
        }
    }
    
    private var islandHeight: CGFloat {
        if state.isShowingVolumeHUD {
            return 36
        }
        if state.isDodging {
            return 4 // Menyusut ke atas (4pt) agar tab browser di belakangnya bisa diklik!
        }
        switch state.mode {
        case .compact:
            return 34
        case .expanded:
            return 205
        }
    }
    
    private var cornerRadius: CGFloat {
        if state.isShowingVolumeHUD {
            return 18
        }
        if state.isDodging {
            return 2
        }
        switch state.mode {
        case .compact:
            return islandHeight / 2 // Kapsul melayang sempurna (Pill)
        case .expanded:
            return 26
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // MARK: - Solid Black Floating Pill (Gaya Nusa & Apple Asli)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(state.isDodging ? 0.05 : 0.42), radius: 14, x: 0, y: 7)
                    .overlay(
                        // Konten dinamis
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
                        .opacity(state.isDodging ? 0 : 1)
                    )
                    .frame(width: islandWidth, height: islandHeight)
                    .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .onTapGesture {
                        state.toggleExpand()
                    }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.74), value: state.mode)
            .animation(.spring(response: 0.20, dampingFraction: 0.70), value: state.isDodging)
            .animation(.spring(response: 0.30, dampingFraction: 0.78), value: state.isShowingVolumeHUD)
            .animation(.easeInOut(duration: 0.2), value: state.activeTab)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 4)
    }
    
    // MARK: - Volume HUD Overlay
    private var volumeHUDContent: some View {
        HStack(spacing: 12) {
            Image(systemName: volumeIcon)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 2)
                .frame(width: 18)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(0, geo.size.width * CGFloat(state.currentVolume) / 100.0), height: 6)
                }
                .frame(height: geo.size.height)
            }
            .frame(height: 6)
            
            Text("\(state.currentVolume)%")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 2)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 14)
    }
    
    private var volumeIcon: String {
        if state.currentVolume == 0 { return "speaker.slash.fill" }
        if state.currentVolume < 33 { return "speaker.wave.1.fill" }
        if state.currentVolume < 66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
    
    // MARK: - 1. Compact View (Jam & Icon DI TENGAH PERSIS)
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
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
            } else if state.isPlaying {
                HStack(spacing: 8) {
                    if let art = state.artworkImage {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 15, height: 15)
                            .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                    } else {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Text(state.trackTitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .lineLimit(1)
                    
                    waveformView(height: 12)
                }
            } else {
                // MARK: - Jam & Icon Tepat di Tengah (Sesuai Permintaan)
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                    
                    Text(currentShortTime)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.35), radius: 2)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
    }
    
    // MARK: - 2. Expanded View (Menu Penuh Liquid Glass)
    private var expandedContent: some View {
        VStack(spacing: 10) {
            // Header Tab Selector (Control | Musik | Notes | Shelf)
            HStack(spacing: 6) {
                ForEach(IslandTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                            state.activeTab = tab
                        }
                    }) {
                        HStack(spacing: 4) {
                            tabIcon(for: tab)
                            Text(tabLabel(for: tab))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            state.activeTab == tab ?
                            Color.white.opacity(0.28) : Color.white.opacity(0.08)
                        )
                        .clipShape(Capsule())
                        .foregroundColor(state.activeTab == tab ? .white : .white.opacity(0.70))
                        .shadow(color: .black.opacity(0.2), radius: 1)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                        state.mode = .compact
                    }
                }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(5)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
            
            Divider()
                .background(Color.white.opacity(0.2))
            
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
        .padding(.bottom, 12)
    }
    
    // MARK: - Tab 1: Control Center View
    private var controlTabView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                // Wi-Fi Tile
                controlTile(
                    icon: "wifi",
                    title: "Wi-Fi",
                    subtitle: state.wifiSSID,
                    isActive: state.isWifiOn,
                    activeColor: .blue
                ) {
                    state.toggleWifi()
                }
                
                // Bluetooth Tile
                controlTile(
                    icon: "dot.radiowaves.left.and.right",
                    title: "Bluetooth",
                    subtitle: state.isBluetoothOn ? "Aktif" : "Mati",
                    isActive: state.isBluetoothOn,
                    activeColor: .blue
                ) {
                    state.toggleBluetooth()
                }
            }
            
            HStack(spacing: 10) {
                // Focus / DND Tile
                controlTile(
                    icon: "moon.fill",
                    title: "Heningkan",
                    subtitle: state.isDNDOn ? "Menyala" : "Mati",
                    isActive: state.isDNDOn,
                    activeColor: .indigo
                ) {
                    state.toggleDND()
                }
                
                // Focus Timer Quick Button
                controlTile(
                    icon: "timer",
                    title: "Focus (25m)",
                    subtitle: state.isTimerRunning ? state.timerFormattedString : "Mulai",
                    isActive: state.isTimerRunning,
                    activeColor: .orange
                ) {
                    state.toggleTimer()
                }
            }
            
            // Volume Slider Bar
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: volumeIcon)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                    Text("Volume Suara")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text("\(state.currentVolume)%")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .shadow(color: .black.opacity(0.2), radius: 1)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.25))
                            .frame(height: 6)
                        Capsule()
                            .fill(Color.white)
                            .frame(width: max(0, geo.size.width * CGFloat(state.currentVolume) / 100.0), height: 6)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { val in
                                let fraction = max(0, min(1.0, val.location.x / geo.size.width))
                                state.updateVolume(Int(fraction * 100))
                            }
                    )
                }
                .frame(height: 6)
            }
            .padding(.top, 2)
        }
    }
    
    private func controlTile(icon: String, title: String, subtitle: String, isActive: Bool, activeColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isActive ? activeColor : Color.white.opacity(0.20))
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 1)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Tab 2: Music View
    private var musicTabView: some View {
        VStack(spacing: 10) {
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
                                colors: [Color.purple.opacity(0.85), Color.pink.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.3), radius: 4)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.trackTitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1)
                        .lineLimit(1)
                    
                    Text(state.artistName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
                
                Spacer()
                
                waveformView(height: 22)
            }
            
            // Progress Bar
            VStack(spacing: 3) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.25))
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
                        .foregroundColor(.white.opacity(0.75))
                    
                    Spacer()
                    
                    Text(state.totalDuration)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                }
            }
            
            // Playback Controls
            HStack(spacing: 30) {
                Button(action: { state.previousTrack() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
                
                Button(action: { state.togglePlayPause() }) {
                    Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                Button(action: { state.nextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: volumeIcon)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                    Text("\(state.currentVolume)%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    // MARK: - Tab 3: Notes & To-Do List View
    private var notesTabView: some View {
        VStack(spacing: 8) {
            // Input field
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                
                TextField("Tulis catatan / to-do, lalu tekan Enter...", text: $state.newTodoText, onCommit: {
                    state.addTodo()
                })
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            // Scrollable List
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(state.todos) { todo in
                        HStack(spacing: 8) {
                            Button(action: { state.toggleTodo(id: todo.id) }) {
                                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(todo.isDone ? .green : .white.opacity(0.55))
                            }
                            .buttonStyle(.plain)
                            
                            Text(todo.text)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(todo.isDone ? .white.opacity(0.5) : .white)
                                .strikethrough(todo.isDone, color: .white.opacity(0.5))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Button(action: { state.deleteTodo(id: todo.id) }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            .frame(height: 80)
            
            // Footer Info
            HStack {
                Text("\(state.todos.filter { !$0.isDone }.count) tugas tersisa")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
                
                Spacer()
                
                if state.todos.contains(where: { $0.isDone }) {
                    Button(action: { state.clearCompletedTodos() }) {
                        Text("Hapus Selesai")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Tab 4: File Shelf View
    private var shelfTabView: some View {
        VStack(spacing: 8) {
            if state.shelfFiles.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                        .fill(isDropTargeted ? Color.green : Color.white.opacity(0.3))
                    
                    VStack(spacing: 4) {
                        Image(systemName: "tray.and.arrow.down")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                        Text("Drop file di sini untuk disimpan sementara")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                .frame(height: 80)
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
                            .background(Color.white.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .onDrag { NSItemProvider(contentsOf: url)! }
                        }
                    }
                }
                .frame(height: 52)
                
                HStack {
                    Text("\(state.shelfFiles.count) file siap di-drag keluar")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Button(action: { state.clearShelf() }) {
                        Text("Bersihkan")
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
        HStack(spacing: 2.5) {
            ForEach(0..<state.waveHeights.count, id: \.self) { idx in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.green)
                    .frame(width: 2.5, height: max(3, height * state.waveHeights[idx]))
            }
        }
    }
    
    private var currentShortTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}
