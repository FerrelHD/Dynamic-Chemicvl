import Foundation
import Combine
import SwiftUI
import AppKit
import IOBluetooth

public enum IslandMode: Equatable {
    case compact
    case expanded
}

public enum IslandTab: String, CaseIterable {
    case control = "Controls"
    case music = "Music"
    case notes = "Reminders"
    case devices = "Devices"
    case shelf = "Shelf"
}

public enum AnimationStyle: String, CaseIterable, Identifiable {
    case bouncy = "Bouncy"
    case smooth = "Smooth"
    case snappy = "Snappy"
    
    public var id: String { rawValue }
    
    public var springAnimation: Animation {
        switch self {
        case .bouncy:
            return .spring(response: 0.38, dampingFraction: 0.68)
        case .smooth:
            return .spring(response: 0.35, dampingFraction: 0.82)
        case .snappy:
            return .spring(response: 0.26, dampingFraction: 0.85)
        }
    }
}

public struct ConnectedDevice: Identifiable, Equatable {
    public let id = UUID()
    public let name: String
    public let batteryLevel: Int
    public let iconName: String
    public let isCharging: Bool
    public let isConnected: Bool
    public let subtitle: String
    
    public init(name: String, batteryLevel: Int, iconName: String, isCharging: Bool, isConnected: Bool = true, subtitle: String) {
        self.name = name
        self.batteryLevel = batteryLevel
        self.iconName = iconName
        self.isCharging = isCharging
        self.isConnected = isConnected
        self.subtitle = subtitle
    }
}

public struct TodoItem: Identifiable, Codable, Equatable {
    public var id = UUID()
    public var text: String
    public var isDone: Bool = false
    public var createdAt: Date = Date()
    
    public init(id: UUID = UUID(), text: String, isDone: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.isDone = isDone
        self.createdAt = createdAt
    }
}

public class IslandState: ObservableObject {
    public static let shared = IslandState()
    
    // UI State: Saran 1 (Klik untuk Buka, Klik di Luar untuk Tutup)
    public var onModeChangedToExpanded: (() -> Void)?
    @Published public var mode: IslandMode = .compact {
        didSet {
            if mode == .expanded {
                onModeChangedToExpanded?()
            }
        }
    }
    @Published public var activeTab: IslandTab = .devices {
        didSet {
            if activeTab == .devices {
                refreshConnectedDevices()
            }
        }
    }
    
    // Hover Peek & Fullscreen Auto-Hide Mode
    @Published public var isHoverPeekEnabled: Bool = true
    public var onHoverRevealed: (() -> Void)?
    @Published public var isHoverRevealed: Bool = false {
        didSet {
            if isHoverRevealed {
                onHoverRevealed?()
            }
        }
    }
    @Published public var isFullScreenAppActive: Bool = false
    private let hoverPeekStorageKey = "DynamicIsland_HoverPeekEnabled"
    
    // Seamless Black Menu Bar (Match Notch)
    @Published public var isSeamlessMenuBarEnabled: Bool = false
    private let seamlessMenuBarStorageKey = "DynamicIsland_SeamlessMenuBarEnabled"
    
    public var isIslandVisible: Bool {
        if mode == .expanded { return true }
        if isShowingVolumeHUD || isShowingBatteryHUD || isShowingWifiHUD || isShowingBluetoothHUD || isShowingCapsLockHUD { return true }
        
        // Auto-Hide when an app is Fullscreen (only reveal on hover peek)
        if isFullScreenAppActive {
            return isHoverRevealed
        }
        
        // When not in fullscreen (Desktop / Windowed), always present as idle standby!
        return isHoverPeekEnabled ? true : true
    }
    
    // MARK: - Dynamic Adaptive Dimensions for Physical NSWindow Frame
    public var currentDimensions: (width: CGFloat, height: CGFloat) {
        if !isIslandVisible {
            return (width: 48, height: 4)
        }
        switch mode {
        case .compact:
            return compactDimensions
        case .expanded:
            return expandedDimensions
        }
    }
    
    public var compactDimensions: (width: CGFloat, height: CGFloat) {
        if isShowingBatteryHUD || isShowingWifiHUD || isShowingBluetoothHUD {
            return (width: 280, height: 42)
        }
        if isShowingVolumeHUD {
            return (width: 280, height: 42)
        }
        if isShowingCapsLockHUD {
            return (width: 220, height: 40)
        }
        if isTimerRunning {
            return (width: 170, height: 30)
        } else if isPlaying {
            let titleLen = CGFloat(trackTitle.count)
            return (width: max(185, min(270, 155 + titleLen * 3.4)), height: 30)
        } else {
            return (width: 142, height: 28) // Sleek Apple compact notch with comfortable horizontal breathing room
        }
    }
    
    public var expandedDimensions: (width: CGFloat, height: CGFloat) {
        if isShowingSettings {
            return (width: 448, height: 218) // Clean spacious settings pane with custom numerical sliders
        }
        if activeTab == .music && isLyricsEnabled {
            return (width: 700, height: 228) // Spacious Responsive Split View for Apple Music Lyrics
        }
        switch activeTab {
        case .devices:
            return (width: 448, height: 198) // 4 device cards + battery info pill with bottom clearance
        case .music:
            return (width: 448, height: 175) // Content-hugging: artwork, scrubber & playback controls
        case .control:
            return (width: 448, height: 206) // Controls center: 5 tiles, CPU/RAM meters, volume slider
        case .notes:
            return (width: 448, height: 202) // Reminders / To-do list with clean footer divider and spacing
        case .shelf:
            return (width: 448, height: 198) // File shelf & clipboard
        }
    }
    
    // Volume & Mute HUD overlay
    @Published public var isShowingVolumeHUD: Bool = false
    @Published public var currentVolume: Int = 50
    @Published public var isMuted: Bool = false
    private var volumeHUDWorkItem: DispatchWorkItem?
    
    // Battery & MagSafe HUD overlay
    @Published public var isShowingBatteryHUD: Bool = false
    @Published public var batteryLevel: Int = 100
    @Published public var isBatteryCharging: Bool = false
    @Published public var isPowerPlugged: Bool = false
    private var batteryHUDWorkItem: DispatchWorkItem?
    
    // Wi-Fi HUD overlay
    @Published public var isShowingWifiHUD: Bool = false
    @Published public var wifiHUDSubtitle: String = ""
    private var wifiHUDWorkItem: DispatchWorkItem?
    
    // Bluetooth & AirPods HUD overlay
    @Published public var isShowingBluetoothHUD: Bool = false
    @Published public var bluetoothHUDSubtitle: String = ""
    @Published public var bluetoothDeviceName: String = ""
    @Published public var bluetoothDeviceIcon: String = "wave.3.forward"
    @Published public var bluetoothDeviceBattery: Int? = nil
    private var bluetoothHUDWorkItem: DispatchWorkItem?
    
    // Bluetooth Device Connection Monitor
    private var lastKnownConnectedAddresses: Set<String> = []
    private var hasInitializedBluetoothDevices: Bool = false
    private var bluetoothWatcherTimer: Timer?
    
    // Caps Lock HUD overlay
    @Published public var isShowingCapsLockHUD: Bool = false
    @Published public var isCapsLockOn: Bool = false
    private var capsLockHUDWorkItem: DispatchWorkItem?
    
    // Control Center Status
    @Published public var isWifiOn: Bool = true
    @Published public var wifiSSID: String = "Wi-Fi"
    @Published public var isBluetoothOn: Bool = true
    @Published public var isMicMuted: Bool = false
    @Published public var isDNDOn: Bool = false
    @Published public var isCaffeinated: Bool = false
    
    // Connected Devices & Accessories Battery Hub
    @Published public var connectedDevices: [ConnectedDevice] = []
    
    // System Hardware Stats (CPU & RAM)
    @Published public var cpuUsage: Int = 10
    @Published public var ramUsageGB: Double = 5.0
    @Published public var ramTotalGB: Double = 8.0
    @Published public var ramPercent: Int = 60
    
    // Media / Universal Now Playing
    @Published public var trackTitle: String = "No Media Playing"
    @Published public var artistName: String = "Play music or video from any app"
    @Published public var albumName: String = ""
    @Published public var isPlaying: Bool = false
    @Published public var playbackProgress: Double = 0.0
    @Published public var currentTime: String = "0:00"
    @Published public var totalDuration: String = "0:00"
    @Published public var remainingTime: String = "-0:00"
    @Published public var artworkImage: NSImage? = nil
    @Published public var currentPositionSeconds: Double = 0.0
    @Published public var totalDurationSeconds: Double = 0.0
    
    // Apple Music Style Synchronized Lyrics
    @Published public var isLyricsEnabled: Bool = false
    @Published public var lyricsLines: [LyricLine] = []
    @Published public var currentLyricIndex: Int? = nil
    @Published public var isLoadingLyrics: Bool = false
    @Published public var lyricsErrorMessage: String? = nil
    @Published public var lyricSyncOffset: Double = 0.0
    private var lastLoadedLyricsTrack: String = ""
    
    // Waveform simulation
    @Published public var waveHeights: [CGFloat] = [0.2, 0.5, 0.3, 0.7, 0.4, 0.6, 0.3]
    private var waveformCancellable: AnyCancellable?
    private var playbackTickerCancellable: AnyCancellable?
    private var playbackAnchorPosition: Double = 0.0
    private var playbackAnchorTime: Date = Date()
    
    // Focus / Pomodoro Timer
    @Published public var timerRemainingSeconds: Int = 25 * 60
    @Published public var timerTotalSeconds: Int = 25 * 60
    @Published public var isTimerRunning: Bool = false
    private var timerCancellable: AnyCancellable?
    
    // Quick Notes & To-Do List (Persistent)
    @Published public var todos: [TodoItem] = []
    @Published public var newTodoText: String = ""
    private let todosStorageKey = "DynamicIsland_SavedTodos"
    
    // File Shelf & Clipboard History
    @Published public var shelfSegment: Int = 0 // 0: Files, 1: Clipboard
    @Published public var shelfFiles: [URL] = []
    @Published public var clipboardHistory: [String] = []
    @Published public var copiedClipIndex: Int? = nil
    private var copyFeedbackWorkItem: DispatchWorkItem?
    
    // Settings & Customization
    @Published public var isShowingSettings: Bool = false
    @Published public var animationStyle: AnimationStyle = .bouncy
    private let animStyleStorageKey = "notchflow_anim_style"
    
    // Live Customizable Numerical Animation Physics
    @Published public var customBounciness: Double = 0.68 // Damping fraction: 0.45 (bouncy) .. 1.00 (rigid)
    @Published public var customDuration: Double = 0.35   // Response duration: 0.20s (snappy) .. 0.55s (slow)
    private let customBouncinessKey = "notchflow_custom_bounciness"
    private let customDurationKey = "notchflow_custom_duration"
    
    public var activeSpringAnimation: Animation {
        return .spring(response: customDuration, dampingFraction: customBounciness)
    }
    
    public init() {
        loadTodos()
        
        if let savedAnim = UserDefaults.standard.string(forKey: animStyleStorageKey),
           let style = AnimationStyle(rawValue: savedAnim) {
            self.animationStyle = style
        }
        
        if UserDefaults.standard.object(forKey: customBouncinessKey) != nil {
            let val = UserDefaults.standard.double(forKey: customBouncinessKey)
            if val >= 0.45 && val <= 1.00 { self.customBounciness = val }
        }
        if UserDefaults.standard.object(forKey: customDurationKey) != nil {
            let val = UserDefaults.standard.double(forKey: customDurationKey)
            if val >= 0.20 && val <= 0.55 { self.customDuration = val }
        }
        
        if UserDefaults.standard.object(forKey: hoverPeekStorageKey) != nil {
            self.isHoverPeekEnabled = UserDefaults.standard.bool(forKey: hoverPeekStorageKey)
        } else {
            self.isHoverPeekEnabled = true
        }
        
        if UserDefaults.standard.object(forKey: seamlessMenuBarStorageKey) != nil {
            self.isSeamlessMenuBarEnabled = UserDefaults.standard.bool(forKey: seamlessMenuBarStorageKey)
        } else {
            self.isSeamlessMenuBarEnabled = MenuBarTintService.shared.isSeamlessActive
        }
        
        if let audio = AudioService.shared.getSystemAudioState() {
            self.currentVolume = audio.volume
            self.isMuted = audio.isMuted
        }
        self.isMicMuted = AudioService.shared.isMicMuted()
        
        refreshControlStatus()
        
        // Monitoring Media Universal otomatis
        MediaService.shared.startMonitoring { [weak self] info in
            guard let self = self else { return }
            
            // Sticky Music Session: protect existing music session from transient social feed audio (IG Reels, TikTok, etc.)
            let hasActiveMusic = !self.trackTitle.isEmpty && self.trackTitle != "No Media Playing"
            if info.isTransientSocial && hasActiveMusic {
                // Ignore transient audio overtaking the music session
                return
            }
            
            // Graceful retention: if no media is playing, keep the last known track in paused state rather than wiping it immediately
            if info.title == "No Media Playing" && hasActiveMusic {
                if self.isPlaying {
                    self.isPlaying = false
                    self.updateWaveformTimer()
                    self.updatePlaybackTicker()
                }
                return
            }
            
            let wasPlaying = self.isPlaying
            let trackChanged = (self.trackTitle != info.title || self.artistName != info.artist)
            
            self.isPlaying = info.isPlaying
            self.trackTitle = info.title
            self.artistName = info.artist
            self.albumName = info.album
            self.totalDurationSeconds = info.duration
            
            if let artData = info.artworkData, !artData.isEmpty, let img = NSImage(data: artData) {
                self.artworkImage = img
            } else if trackChanged || self.artworkImage == nil {
                if !info.title.isEmpty && info.title != "No Media Playing" {
                    MediaService.shared.fetchOnlineArtwork(title: info.title, artist: info.artist, album: info.album) { [weak self] onlineData in
                        if let onlineData = onlineData, let img = NSImage(data: onlineData) {
                            self?.artworkImage = img
                        }
                    }
                } else {
                    self.artworkImage = nil
                }
            }
            
            // Sync anchor if track changed, stopped, or drifted more than 0.6s
            let currentEstimated = self.playbackAnchorPosition + (self.isPlaying ? Date().timeIntervalSince(self.playbackAnchorTime) : 0)
            if trackChanged || !self.isPlaying || abs(currentEstimated - info.position) > 0.6 {
                self.playbackAnchorPosition = info.position
                self.playbackAnchorTime = Date()
                self.currentPositionSeconds = info.position
            }
            
            if self.totalDurationSeconds.isFinite && !self.totalDurationSeconds.isNaN && self.totalDurationSeconds > 0 {
                let dur = max(0.1, self.totalDurationSeconds)
                let pos = max(0, min(dur, (self.currentPositionSeconds.isFinite && !self.currentPositionSeconds.isNaN) ? self.currentPositionSeconds : 0))
                self.playbackProgress = max(0, min(1.0, pos / dur))
                self.currentTime = self.formatTime(self.safeSeconds(pos))
                self.totalDuration = self.formatTime(self.safeSeconds(dur))
                let rem = max(0, dur - pos)
                self.remainingTime = "-\(self.formatTime(self.safeSeconds(rem)))"
            } else {
                self.playbackProgress = 0
                self.currentTime = "0:00"
                self.totalDuration = "0:00"
                self.remainingTime = "-0:00"
            }
            
            if self.isPlaying != wasPlaying {
                if self.isPlaying {
                    self.playbackAnchorPosition = info.position
                    self.playbackAnchorTime = Date()
                }
                self.updateWaveformTimer()
                self.updatePlaybackTicker()
            }
            
            if trackChanged {
                self.lastLoadedLyricsTrack = ""
                if self.isLyricsEnabled {
                    self.loadLyrics(force: true)
                } else {
                    self.lyricsLines = []
                    self.currentLyricIndex = nil
                }
            }
        }
        
        // Monitoring Volume & Mute HUD otomatis
        AudioService.shared.startMonitoring { [weak self] newVolume, isMuted in
            self?.triggerVolumeHUD(level: newVolume, isMuted: isMuted)
        }
        
        // Monitoring Bluetooth Device Connections (AirPods & Accessories)
        startBluetoothDeviceMonitoring()
        
        // Monitoring Battery & MagSafe Status
        let initialBattery = BatteryService.shared.getStatus()
        self.batteryLevel = initialBattery.level
        self.isBatteryCharging = initialBattery.isCharging
        self.isPowerPlugged = initialBattery.isPlugged
        refreshConnectedDevices()
        
        BatteryService.shared.startMonitoring { [weak self] status, powerChanged in
            guard let self = self else { return }
            self.batteryLevel = status.level
            self.isBatteryCharging = status.isCharging
            self.isPowerPlugged = status.isPlugged
            self.refreshConnectedDevices()
            
            if powerChanged {
                self.triggerBatteryHUD()
            }
        }
        
        // Monitoring Caps Lock State
        CapsLockService.shared.startMonitoring { [weak self] isOn in
            self?.triggerCapsLockHUD(isOn: isOn)
        }
        
        // Monitoring Clipboard History
        if let initialClip = ClipboardService.shared.getCurrentClipboard() {
            self.clipboardHistory.append(initialClip)
        }
        ClipboardService.shared.startMonitoring { [weak self] newText in
            guard let self = self else { return }
            if self.clipboardHistory.first != newText {
                self.clipboardHistory.insert(newText, at: 0)
                if self.clipboardHistory.count > 20 {
                    self.clipboardHistory.removeLast()
                }
            }
        }
    }
    
    // MARK: - Toggle Expand & Minimize (Bouncy Elastic Spring Physics)
    public func toggleExpand() {
        if isShowingVolumeHUD {
            isShowingVolumeHUD = false
        }
        refreshControlStatus()
        
        let willExpand = (mode == .compact)
        if willExpand {
            isHoverRevealed = true
            onModeChangedToExpanded?()
        }
        withAnimation(activeSpringAnimation) {
            if willExpand {
                mode = .expanded
            } else {
                mode = .compact
                isShowingSettings = false
            }
        }
    }
    
    public func minimize() {
        withAnimation(activeSpringAnimation) {
            self.mode = .compact
            self.isShowingSettings = false
        }
    }
    
    // MARK: - Swift Swipe Navigation (Next & Previous Tab)
    public func nextTab() {
        let all = IslandTab.allCases
        guard let idx = all.firstIndex(of: activeTab) else { return }
        let nextIdx = (idx + 1) % all.count
        withAnimation(activeSpringAnimation) {
            isShowingSettings = false
            activeTab = all[nextIdx]
        }
    }
    
    public func previousTab() {
        let all = IslandTab.allCases
        guard let idx = all.firstIndex(of: activeTab) else { return }
        let prevIdx = (idx - 1 + all.count) % all.count
        withAnimation(activeSpringAnimation) {
            isShowingSettings = false
            activeTab = all[prevIdx]
        }
    }
    
    public func setAnimationStyle(_ style: AnimationStyle) {
        self.animationStyle = style
        switch style {
        case .bouncy:
            setCustomBounciness(0.65)
            setCustomDuration(0.38)
        case .smooth:
            setCustomBounciness(0.82)
            setCustomDuration(0.35)
        case .snappy:
            setCustomBounciness(0.86)
            setCustomDuration(0.25)
        }
        UserDefaults.standard.set(style.rawValue, forKey: animStyleStorageKey)
    }
    
    public func setCustomBounciness(_ value: Double) {
        customBounciness = max(0.45, min(1.00, value))
        UserDefaults.standard.set(customBounciness, forKey: customBouncinessKey)
    }
    
    public func setCustomDuration(_ value: Double) {
        customDuration = max(0.20, min(0.55, value))
        UserDefaults.standard.set(customDuration, forKey: customDurationKey)
    }
    
    public func resetAnimationDefaults() {
        setCustomBounciness(0.68)
        setCustomDuration(0.35)
        self.animationStyle = .bouncy
        UserDefaults.standard.set(animationStyle.rawValue, forKey: animStyleStorageKey)
    }
    
    // MARK: - Hover Peek Mode Action
    public func toggleHoverPeek() {
        withAnimation(.easeInOut(duration: 0.20)) {
            isHoverPeekEnabled.toggle()
        }
        UserDefaults.standard.set(isHoverPeekEnabled, forKey: hoverPeekStorageKey)
        if !isHoverPeekEnabled {
            isHoverRevealed = true
        }
    }
    
    // MARK: - Control Center Actions
    public func refreshControlStatus() {
        SystemControlService.shared.getWifiStatus { [weak self] isEnabled, ssid in
            self?.isWifiOn = isEnabled
            self?.wifiSSID = ssid
        }
        
        let stats = SystemStatsService.shared.getStats()
        self.cpuUsage = stats.cpuPercent
        self.ramUsageGB = stats.ramUsedGB
        self.ramTotalGB = stats.ramTotalGB
        self.ramPercent = stats.ramPercent
    }
    
    public func toggleWifi() {
        SystemControlService.shared.toggleWifi(currentlyEnabled: isWifiOn) { [weak self] newState in
            self?.isWifiOn = newState
            self?.refreshControlStatus()
            self?.triggerWifiHUD(connected: newState)
        }
    }
    
    public func toggleBluetooth() {
        SystemControlService.shared.toggleBluetooth(currentlyEnabled: isBluetoothOn) { [weak self] newState in
            self?.isBluetoothOn = newState
            self?.triggerBluetoothHUD(connected: newState)
        }
    }
    
    public func toggleMicMute() {
        self.isMicMuted = AudioService.shared.toggleMicrophoneMute()
    }
    
    public func toggleDND() {
        SystemControlService.shared.toggleDoNotDisturb(currentlyEnabled: isDNDOn) { [weak self] newState in
            self?.isDNDOn = newState
        }
    }
    
    public func toggleCaffeinate() {
        self.isCaffeinated = SystemControlService.shared.toggleCaffeinate()
    }
    
    public func updateVolume(_ newVol: Int) {
        currentVolume = newVol
        AudioService.shared.setSystemVolume(newVol)
    }
    
    // MARK: - To-Do & Notes Actions
    public func addTodo() {
        let trimmed = newTodoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = TodoItem(text: trimmed)
        todos.insert(item, at: 0)
        newTodoText = ""
        saveTodos()
    }
    
    public func toggleTodo(id: UUID) {
        if let idx = todos.firstIndex(where: { $0.id == id }) {
            todos[idx].isDone.toggle()
            saveTodos()
        }
    }
    
    public func deleteTodo(id: UUID) {
        todos.removeAll { $0.id == id }
        saveTodos()
    }
    
    public func clearCompletedTodos() {
        todos.removeAll { $0.isDone }
        saveTodos()
    }
    
    private func saveTodos() {
        if let encoded = try? JSONEncoder().encode(todos) {
            UserDefaults.standard.set(encoded, forKey: todosStorageKey)
        }
    }
    
    private func loadTodos() {
        if let data = UserDefaults.standard.data(forKey: todosStorageKey),
           let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) {
            self.todos = decoded
        } else {
            self.todos = [
                TodoItem(text: "Explore Dynamic Island on Mac", isDone: true),
                TodoItem(text: "Play a song on Spotify or YouTube", isDone: false)
            ]
        }
    }
    
    // MARK: - Volume & Mute HUD Trigger
    public func triggerVolumeHUD(level: Int, isMuted: Bool = false) {
        currentVolume = level
        self.isMuted = isMuted
        
        // Root cause fix: If notch is expanded, update volume/mute in background without hijacking the view!
        guard mode != .expanded else { return }
        
        volumeHUDWorkItem?.cancel()
        
        withAnimation(.easeInOut(duration: 0.18)) {
            isShowingVolumeHUD = true
        }
        
        let work = DispatchWorkItem { [weak self] in
            withAnimation(.easeInOut(duration: 0.20)) {
                self?.isShowingVolumeHUD = false
            }
        }
        volumeHUDWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }
    
    public func triggerVolumeHUD(_ level: Int) {
        triggerVolumeHUD(level: level, isMuted: self.isMuted)
    }
    
    // MARK: - Battery & MagSafe HUD Trigger (Option 2: 3-Column Pill)
    public func triggerBatteryHUD() {
        guard mode != .expanded else { return }
        batteryHUDWorkItem?.cancel()
        
        withAnimation(.easeInOut(duration: 0.20)) {
            isShowingBatteryHUD = true
        }
        
        let work = DispatchWorkItem { [weak self] in
            withAnimation(.easeInOut(duration: 0.20)) {
                self?.isShowingBatteryHUD = false
            }
        }
        batteryHUDWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
    }
    
    // MARK: - Wi-Fi Connection HUD Trigger
    public func triggerWifiHUD(connected: Bool, ssid: String? = nil) {
        guard mode != .expanded else { return }
        wifiHUDWorkItem?.cancel()
        isWifiOn = connected
        if let s = ssid, !s.isEmpty {
            wifiSSID = s
        }
        wifiHUDSubtitle = connected ? (wifiSSID.isEmpty ? "Connected" : "Connected • \(wifiSSID)") : "Disconnected"
        
        withAnimation(.easeInOut(duration: 0.20)) {
            isShowingWifiHUD = true
        }
        
        let work = DispatchWorkItem { [weak self] in
            withAnimation(.easeInOut(duration: 0.20)) {
                self?.isShowingWifiHUD = false
            }
        }
        wifiHUDWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: work)
    }
    
    // MARK: - Bluetooth & AirPods Connection HUD Trigger
    public func triggerBluetoothHUD(connected: Bool, device: String? = nil, icon: String = "wave.3.forward", battery: Int? = nil) {
        guard mode != .expanded else { return }
        bluetoothHUDWorkItem?.cancel()
        isBluetoothOn = connected
        if let d = device, !d.isEmpty {
            bluetoothDeviceName = d
            bluetoothDeviceIcon = icon
            bluetoothDeviceBattery = battery
        } else {
            bluetoothDeviceName = ""
            bluetoothDeviceIcon = "wave.3.forward"
            bluetoothDeviceBattery = nil
        }
        bluetoothHUDSubtitle = connected ? (bluetoothDeviceName.isEmpty ? "Connected" : "Connected • \(bluetoothDeviceName)") : "Disconnected"
        
        withAnimation(.easeInOut(duration: 0.20)) {
            isShowingBluetoothHUD = true
        }
        
        let work = DispatchWorkItem { [weak self] in
            withAnimation(.easeInOut(duration: 0.20)) {
                self?.isShowingBluetoothHUD = false
            }
        }
        bluetoothHUDWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
    }
    
    // MARK: - Bluetooth Device Connection Monitoring
    private func startBluetoothDeviceMonitoring() {
        if let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] {
            let connected = paired.filter { $0.isConnected() }
            for dev in connected {
                if let addr = dev.addressString {
                    lastKnownConnectedAddresses.insert(addr)
                }
            }
            hasInitializedBluetoothDevices = true
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.bluetoothWatcherTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.checkBluetoothDeviceConnections()
            }
        }
    }
    
    private func checkBluetoothDeviceConnections() {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return }
        let connected = paired.filter { $0.isConnected() }
        let currentAddrs = Set(connected.compactMap { $0.addressString })
        
        guard hasInitializedBluetoothDevices else {
            lastKnownConnectedAddresses = currentAddrs
            hasInitializedBluetoothDevices = true
            return
        }
        
        let newlyConnected = connected.filter { dev in
            guard let addr = dev.addressString else { return false }
            return !lastKnownConnectedAddresses.contains(addr)
        }
        
        if let newDev = newlyConnected.first {
            let name = newDev.nameOrAddress ?? newDev.name ?? "Bluetooth Device"
            let lower = name.lowercased()
            let minor = Int(newDev.deviceClassMinor)
            
            let icon: String
            if lower.contains("airpod") || lower.contains("bud") {
                icon = "airpodspro"
            } else if lower.contains("mouse") || minor == 32 {
                icon = "magicmouse"
            } else if lower.contains("keyboard") {
                icon = "keyboard"
            } else if lower.contains("trackpad") {
                icon = "computermouse"
            } else if lower.contains("bean") || lower.contains("speaker") || minor == 1 || minor == 16 {
                icon = "headphones"
            } else {
                icon = "wave.3.forward"
            }
            
            let hidMap = getHIDBatteryLevels()
            let airPodsBattery = getAirPodsBatteryLevel()
            var batt: Int? = nil
            if let matched = hidMap[lower] {
                batt = matched
            } else if lower.contains("airpod"), let ap = airPodsBattery {
                batt = ap
            }
            
            triggerBluetoothHUD(connected: true, device: name, icon: icon, battery: batt)
            refreshConnectedDevices()
        } else if currentAddrs != lastKnownConnectedAddresses {
            refreshConnectedDevices()
        }
        
        lastKnownConnectedAddresses = currentAddrs
    }
    
    // MARK: - Caps Lock HUD Trigger
    public func triggerCapsLockHUD(isOn: Bool) {
        guard mode != .expanded else { return }
        isCapsLockOn = isOn
        capsLockHUDWorkItem?.cancel()
        
        withAnimation(.easeInOut(duration: 0.18)) {
            isShowingCapsLockHUD = true
        }
        
        let work = DispatchWorkItem { [weak self] in
            withAnimation(.easeInOut(duration: 0.20)) {
                self?.isShowingCapsLockHUD = false
            }
        }
        capsLockHUDWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: work)
    }
    
    // MARK: - Media Controls Universal
    public func togglePlayPause() {
        MediaService.shared.togglePlayPause()
    }
    
    public func nextTrack() {
        MediaService.shared.nextTrack()
    }
    
    public func previousTrack() {
        MediaService.shared.previousTrack()
    }
    
    public func seekTo(_ seconds: Double) {
        guard seconds.isFinite && !seconds.isNaN else { return }
        let validDuration = (totalDurationSeconds.isFinite && !totalDurationSeconds.isNaN && totalDurationSeconds > 0) ? totalDurationSeconds : 0
        currentPositionSeconds = max(0, min(validDuration > 0 ? validDuration : seconds, seconds))
        if validDuration > 0 {
            playbackProgress = max(0, min(1.0, currentPositionSeconds / validDuration))
            currentTime = formatTime(safeSeconds(currentPositionSeconds))
            let rem = max(0, validDuration - currentPositionSeconds)
            remainingTime = "-\(formatTime(safeSeconds(rem)))"
        }
        updateActiveLyricIndex(for: currentPositionSeconds)
        MediaService.shared.seek(to: currentPositionSeconds)
    }
    
    // MARK: - Synchronized Lyrics Engine
    public func toggleLyrics() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            isLyricsEnabled.toggle()
        }
        if isLyricsEnabled {
            // Slight deferral so network request/loading state doesn't hitch the opening spring animation frame
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.loadLyrics()
            }
        }
    }
    
    public func loadLyrics(force: Bool = false) {
        guard !trackTitle.isEmpty && trackTitle != "No Media Playing" else { return }
        let currentTrackKey = "\(trackTitle)_\(artistName)"
        if !force && lastLoadedLyricsTrack == currentTrackKey && !lyricsLines.isEmpty { return }
        
        lastLoadedLyricsTrack = currentTrackKey
        isLoadingLyrics = true
        lyricsErrorMessage = nil
        
        LyricsService.shared.fetchLyrics(title: trackTitle, artist: artistName) { [weak self] result in
            guard let self = self else { return }
            self.isLoadingLyrics = false
            switch result {
            case .success(let lines):
                self.lyricsLines = lines
                self.lyricsErrorMessage = nil
                self.updateActiveLyricIndex(for: self.currentPositionSeconds)
            case .failure:
                self.lyricsLines = []
                self.lyricsErrorMessage = "No lyrics found for this track"
            }
        }
    }
    
    public func updateActiveLyricIndex(for position: Double) {
        guard !lyricsLines.isEmpty else {
            if currentLyricIndex != nil { currentLyricIndex = nil }
            return
        }
        let target = position + lyricSyncOffset
        let idx = lyricsLines.lastIndex(where: { $0.timestamp <= target })
        if currentLyricIndex != idx {
            currentLyricIndex = idx
        }
    }
    
    public func adjustLyricSync(by delta: Double) {
        lyricSyncOffset = max(-3.0, min(3.0, lyricSyncOffset + delta))
        updateActiveLyricIndex(for: currentPositionSeconds)
    }
    
    public func resetLyricSync() {
        lyricSyncOffset = 0.0
        updateActiveLyricIndex(for: currentPositionSeconds)
    }
    
    // Physical Multi-Band Equalizer State (7 Bands: Sub-Bass, Bass, Low-Mid, Mid, Upper-Mid, Presence, Brilliance)
    private var currentBandEnergies: [Double] = Array(repeating: 0.20, count: 7)

    // MARK: - On-Demand Physical Multi-Band Equalizer (Attack-Decay Inertia, Zero CPU Idle when Paused)
    private func updateWaveformTimer() {
        if isPlaying {
            if waveformCancellable == nil {
                waveformCancellable = Timer.publish(every: 0.05, on: .main, in: .common)
                    .autoconnect()
                    .sink { [weak self] _ in
                        guard let self = self, self.isPlaying else { return }
                        let t = Date().timeIntervalSinceReferenceDate
                        
                        // Tempo beat clock (~124 BPM typical tempo = ~2.07 Hz)
                        let beatPhase = (t * 2.07).truncatingRemainder(dividingBy: 1.0)
                        let kickImpulse = exp(-beatPhase * 6.0) // sharp transient spike at each beat
                        let snareImpulse = exp(-((beatPhase + 0.5).truncatingRemainder(dividingBy: 1.0)) * 7.0) // off-beat backbeat
                        
                        // Multi-band acoustic targets
                        let targets: [Double] = [
                            0.20 + 0.70 * kickImpulse + 0.15 * sin(t * 4.2), // Sub-bass: heavy kick
                            0.25 + 0.60 * kickImpulse + 0.20 * cos(t * 5.1), // Bass
                            0.30 + 0.40 * sin(t * 8.4) + 0.25 * cos(t * 3.3), // Low-mid
                            0.35 + 0.45 * sin(t * 11.2) + 0.20 * sin(t * 6.5), // Vocal body
                            0.30 + 0.50 * snareImpulse + 0.30 * sin(t * 14.1), // Vocal presence & snare
                            0.25 + 0.45 * snareImpulse + 0.25 * cos(t * 16.7), // Treble / Hi-hat
                            0.20 + 0.35 * abs(sin(t * 19.3)) + 0.15 * cos(t * 9.8) // Air & shimmer
                        ]
                        
                        // Physics update: fast attack (0.04s) and exponential decay (0.18s)
                        for i in 0..<7 {
                            let target = max(0.18, min(1.0, targets[i]))
                            if target > self.currentBandEnergies[i] {
                                // Fast attack
                                self.currentBandEnergies[i] += (target - self.currentBandEnergies[i]) * 0.55
                            } else {
                                // Smooth natural decay
                                self.currentBandEnergies[i] += (target - self.currentBandEnergies[i]) * 0.22
                            }
                        }
                        
                        self.waveHeights = self.currentBandEnergies.map { CGFloat($0) }
                    }
            }
        } else {
            waveformCancellable?.cancel()
            waveformCancellable = nil
            self.currentBandEnergies = Array(repeating: 0.20, count: 7)
            withAnimation(.easeInOut(duration: 0.25)) {
                self.waveHeights = Array(repeating: 0.20, count: 7)
            }
        }
    }
    
    // MARK: - High-Precision Sub-Second Playback Ticker (0.2s Smooth Interpolation, Zero CPU Idle when Paused)
    private func updatePlaybackTicker() {
        if isPlaying {
            if playbackTickerCancellable == nil {
                playbackTickerCancellable = Timer.publish(every: 0.2, on: .main, in: .common)
                    .autoconnect()
                    .sink { [weak self] _ in
                        guard let self = self, self.isPlaying else { return }
                        let elapsed = Date().timeIntervalSince(self.playbackAnchorTime)
                        let exactPos = self.playbackAnchorPosition + elapsed
                        let dur = max(0.1, self.totalDurationSeconds)
                        let clampedPos = max(0, min(dur, exactPos))
                        
                        self.currentPositionSeconds = clampedPos
                        self.playbackProgress = max(0, min(1.0, clampedPos / dur))
                        self.currentTime = self.formatTime(self.safeSeconds(clampedPos))
                        let rem = max(0, dur - clampedPos)
                        self.remainingTime = "-\(self.formatTime(self.safeSeconds(rem)))"
                        
                        if self.isLyricsEnabled {
                            self.updateActiveLyricIndex(for: clampedPos)
                        }
                    }
            }
        } else {
            playbackTickerCancellable?.cancel()
            playbackTickerCancellable = nil
        }
    }
    
    // MARK: - Timer Controls (Zero CPU Idle when Paused)
    public var timerFormattedString: String {
        let mins = timerRemainingSeconds / 60
        let secs = timerRemainingSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    public var timerProgress: Double {
        guard timerTotalSeconds > 0 else { return 0 }
        return Double(timerRemainingSeconds) / Double(timerTotalSeconds)
    }
    
    public func toggleTimer() {
        isTimerRunning.toggle()
        updateTimerRunner()
    }
    
    public func setTimerPreset(minutes: Int) {
        isTimerRunning = false
        timerTotalSeconds = minutes * 60
        timerRemainingSeconds = minutes * 60
        updateTimerRunner()
    }
    
    private func updateTimerRunner() {
        if isTimerRunning {
            if timerCancellable == nil {
                timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
                    .autoconnect()
                    .sink { [weak self] _ in
                        guard let self = self, self.isTimerRunning else { return }
                        if self.timerRemainingSeconds > 0 {
                            self.timerRemainingSeconds -= 1
                        } else {
                            self.isTimerRunning = false
                            self.updateTimerRunner()
                            NSSound.beep()
                        }
                    }
            }
        } else {
            timerCancellable?.cancel()
            timerCancellable = nil
        }
    }
    
    // MARK: - File Shelf Controls (Max 10 items)
    public func addFiles(_ urls: [URL]) {
        for url in urls {
            if !shelfFiles.contains(url) {
                if shelfFiles.count >= 10 {
                    shelfFiles.removeFirst()
                }
                shelfFiles.append(url)
            }
        }
    }
    
    public func removeFile(at index: Int) {
        guard shelfFiles.indices.contains(index) else { return }
        shelfFiles.remove(at: index)
    }
    
    public func clearShelf() {
        shelfFiles.removeAll()
    }
    
    // MARK: - Clipboard History Controls
    public func copyClip(at index: Int) {
        guard clipboardHistory.indices.contains(index) else { return }
        let text = clipboardHistory[index]
        ClipboardService.shared.copyToClipboard(text)
        
        copyFeedbackWorkItem?.cancel()
        copiedClipIndex = index
        let work = DispatchWorkItem { [weak self] in
            self?.copiedClipIndex = nil
        }
        copyFeedbackWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }
    
    public func clearClipboard() {
        clipboardHistory.removeAll()
    }
    
    // MARK: - Seamless Menu Bar Control
    public func toggleSeamlessMenuBar() {
        if isSeamlessMenuBarEnabled {
            let success = MenuBarTintService.shared.restoreOriginalWallpaper()
            if success {
                isSeamlessMenuBarEnabled = false
                UserDefaults.standard.set(false, forKey: seamlessMenuBarStorageKey)
            }
        } else {
            let success = MenuBarTintService.shared.applySeamlessMenuBar()
            if success {
                isSeamlessMenuBarEnabled = true
                UserDefaults.standard.set(true, forKey: seamlessMenuBarStorageKey)
            }
        }
    }
    
    public func restoreOriginalWallpaper() {
        let success = MenuBarTintService.shared.restoreOriginalWallpaper()
        if success {
            isSeamlessMenuBarEnabled = false
            UserDefaults.standard.set(false, forKey: seamlessMenuBarStorageKey)
        }
    }
    
    // MARK: - Connected Devices Battery Hub (Native macOS Real Hardware Detection)
    public func refreshConnectedDevices() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var list: [ConnectedDevice] = []
            
            // 1. MacBook Pro Internal Battery (Real hardware via BatteryService / IOPowerSources)
            let mbStatus = BatteryService.shared.getStatus()
            list.append(ConnectedDevice(
                name: "MacBook Pro",
                batteryLevel: mbStatus.level,
                iconName: "laptopcomputer",
                isCharging: mbStatus.isCharging || mbStatus.isPlugged,
                isConnected: true,
                subtitle: mbStatus.isCharging ? "Charging" : (mbStatus.isPlugged ? "Power Adapter" : "Battery")
            ))
            
            // 2. Query Real Paired Bluetooth Accessories via IOBluetooth
            let hidMap = self.getHIDBatteryLevels()
            let airPodsBattery = self.getAirPodsBatteryLevel()
            
            if let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] {
                var connectedList: [IOBluetoothDevice] = []
                var disconnectedList: [IOBluetoothDevice] = []
                for dev in paired {
                    if dev.isConnected() {
                        connectedList.append(dev)
                    } else {
                        disconnectedList.append(dev)
                    }
                }
                
                // Prioritize user accessories (mouse, airpods, headphones) over generic serial tags
                disconnectedList.sort { d1, d2 in
                    let n1 = (d1.nameOrAddress ?? "").lowercased()
                    let n2 = (d2.nameOrAddress ?? "").lowercased()
                    let s1 = (n1.contains("mouse") || n1.contains("airpod")) ? 1 : 0
                    let s2 = (n2.contains("mouse") || n2.contains("airpod")) ? 1 : 0
                    return s1 > s2
                }
                
                let targetList = connectedList + disconnectedList
                for dev in targetList.prefix(3) {
                    let name = dev.nameOrAddress ?? dev.name ?? "Bluetooth Device"
                    let lower = name.lowercased()
                    let minor = Int(dev.deviceClassMinor)
                    let isConn = dev.isConnected()
                    
                    let icon: String
                    if lower.contains("airpod") || lower.contains("bud") {
                        icon = "airpodspro"
                    } else if lower.contains("mouse") || minor == 32 {
                        icon = "magicmouse"
                    } else if lower.contains("keyboard") {
                        icon = "keyboard"
                    } else if lower.contains("trackpad") {
                        icon = "computermouse"
                    } else if lower.contains("bean") || lower.contains("speaker") || minor == 1 || minor == 16 {
                        icon = "headphones"
                    } else {
                        icon = "wave.3.right"
                    }
                    
                    var level: Int = 0
                    if isConn {
                        if let matched = hidMap[lower] {
                            level = matched
                        } else if lower.contains("mouse"), let m = hidMap.first(where: { $0.key.contains("mouse") }) {
                            level = m.value
                        } else if lower.contains("airpod"), let ap = airPodsBattery {
                            level = ap
                        } else {
                            level = -1 // Connected, hardware doesn't report battery via HID
                        }
                    }
                    
                    list.append(ConnectedDevice(
                        name: name,
                        batteryLevel: level,
                        iconName: icon,
                        isCharging: false,
                        isConnected: isConn,
                        subtitle: isConn ? "Connected" : "Disconnected"
                    ))
                }
            }
            
            DispatchQueue.main.async {
                self.connectedDevices = list
            }
        }
    }
    
    private func getHIDBatteryLevels() -> [String: Int] {
        var map: [String: Int] = [:]
        let task = Process()
        let pipe = Pipe()
        task.launchPath = "/usr/sbin/ioreg"
        task.arguments = ["-c", "AppleDeviceManagementHIDEventService", "-r", "-l"]
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let chunks = output.components(separatedBy: "+-o AppleDeviceManagementHIDEventService")
                for chunk in chunks {
                    var prod = ""
                    var pct = -1
                    for line in chunk.components(separatedBy: "\n") {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.hasPrefix("\"Product\" = ") {
                            prod = trimmed.replacingOccurrences(of: "\"Product\" = \"", with: "").replacingOccurrences(of: "\"", with: "")
                        }
                        if trimmed.hasPrefix("\"BatteryPercent\" = ") {
                            let valStr = trimmed.replacingOccurrences(of: "\"BatteryPercent\" = ", with: "")
                            if let val = Int(valStr) {
                                pct = val
                            }
                        }
                    }
                    if !prod.isEmpty && pct >= 0 {
                        map[prod.lowercased()] = pct
                    }
                }
            }
        } catch {}
        return map
    }
    
    private func getAirPodsBatteryLevel() -> Int? {
        let task = Process()
        let pipe = Pipe()
        task.launchPath = "/usr/sbin/ioreg"
        task.arguments = ["-r", "-k", "BatteryPercentCombined"]
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                for line in output.components(separatedBy: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("\"BatteryPercentCombined\" = ") {
                        let valStr = trimmed.replacingOccurrences(of: "\"BatteryPercentCombined\" = ", with: "")
                        return Int(valStr)
                    }
                }
            }
        } catch {}
        return nil
    }
    
    public func safeSeconds(_ val: Double) -> Int {
        guard val.isFinite, !val.isNaN, val >= 0 else { return 0 }
        if val > 86400 * 365 { return 0 } // Clamp to reasonable duration
        return Int(val)
    }
    
    public func formatTime(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let m = s / 60
        let sec = s % 60
        return String(format: "%d:%02d", m, sec)
    }
}
