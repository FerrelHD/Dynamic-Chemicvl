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
    @Published public var isHoverRevealed: Bool = false
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
        if isShowingBatteryHUD || isShowingWifiHUD || isShowingBluetoothHUD {
            return (width: 280, height: 42)
        }
        if isShowingVolumeHUD {
            return (width: 280, height: 42)
        }
        if isShowingCapsLockHUD {
            return (width: 220, height: 40)
        }
        switch mode {
        case .compact:
            if isTimerRunning {
                return (width: 170, height: 30)
            } else if isPlaying {
                let titleLen = CGFloat(trackTitle.count)
                return (width: max(180, min(230, 150 + titleLen * 3.0)), height: 30)
            } else {
                return (width: 136, height: 28) // Sleek, perfectly proportioned Apple compact notch
            }
        case .expanded:
            return expandedDimensions
        }
    }
    
    public var expandedDimensions: (width: CGFloat, height: CGFloat) {
        if activeTab == .music && isLyricsEnabled {
            return (width: 700, height: 245) // Spacious Responsive Split View for Apple Music Lyrics
        }
        return (width: 448, height: 236) // Unified 236pt height (zero tab switching jumps/clipping)
    }
    
    // Volume HUD overlay
    @Published public var isShowingVolumeHUD: Bool = false
    @Published public var currentVolume: Int = 50
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
    
    // Bluetooth HUD overlay
    @Published public var isShowingBluetoothHUD: Bool = false
    @Published public var bluetoothHUDSubtitle: String = ""
    @Published public var bluetoothDeviceName: String = ""
    private var bluetoothHUDWorkItem: DispatchWorkItem?
    
    // Caps Lock HUD overlay
    @Published public var isShowingCapsLockHUD: Bool = false
    @Published public var isCapsLockOn: Bool = false
    private var capsLockHUDWorkItem: DispatchWorkItem?
    
    // Control Center Status
    @Published public var isWifiOn: Bool = true
    @Published public var wifiSSID: String = "Wi-Fi"
    @Published public var isBluetoothOn: Bool = true
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
    private var lastLoadedLyricsTrack: String = ""
    
    // Waveform simulation
    @Published public var waveHeights: [CGFloat] = [0.2, 0.5, 0.3, 0.7, 0.4, 0.6, 0.3]
    private var waveformCancellable: AnyCancellable?
    private var playbackTickerCancellable: AnyCancellable?
    
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
    
    public init() {
        loadTodos()
        
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
        
        if let vol = AudioService.shared.getSystemVolume() {
            self.currentVolume = vol
        }
        
        refreshControlStatus()
        
        // Monitoring Media Universal otomatis
        MediaService.shared.startMonitoring { [weak self] info in
            guard let self = self else { return }
            let wasPlaying = self.isPlaying
            let trackChanged = (self.trackTitle != info.title || self.artistName != info.artist)
            
            self.isPlaying = info.isPlaying
            self.trackTitle = info.title
            self.artistName = info.artist
            self.albumName = info.album
            self.totalDurationSeconds = info.duration
            
            if let artData = info.artworkData {
                self.artworkImage = NSImage(data: artData)
            } else if trackChanged || self.artworkImage == nil {
                if !info.title.isEmpty && info.title != "No Media Playing" {
                    MediaService.shared.fetchOnlineArtwork(title: info.title, artist: info.artist) { [weak self] onlineData in
                        if let onlineData = onlineData {
                            self?.artworkImage = NSImage(data: onlineData)
                        }
                    }
                } else {
                    self.artworkImage = nil
                }
            }
            
            // Sync position if track changed, stopped, or drifted more than 2 seconds
            if trackChanged || !self.isPlaying || abs(self.currentPositionSeconds - info.position) > 2.0 {
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
            } else {
                self.updateActiveLyricIndex(for: info.position)
            }
        }
        
        // Monitoring Volume HUD otomatis
        AudioService.shared.startMonitoring { [weak self] newVolume in
            self?.triggerVolumeHUD(newVolume)
        }
        
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
                if self.clipboardHistory.count > 12 {
                    self.clipboardHistory.removeLast()
                }
            }
        }
    }
    
    // MARK: - Toggle Expand & Minimize (Snappy Clean Animation)
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
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            if willExpand {
                mode = .expanded
            } else {
                mode = .compact
            }
        }
    }
    
    public func minimize() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            self.mode = .compact
        }
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
    
    // MARK: - Volume HUD Trigger
    public func triggerVolumeHUD(_ level: Int) {
        currentVolume = level
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
    
    // MARK: - Bluetooth Connection HUD Trigger
    public func triggerBluetoothHUD(connected: Bool, device: String? = nil) {
        guard mode != .expanded else { return }
        bluetoothHUDWorkItem?.cancel()
        isBluetoothOn = connected
        if let d = device, !d.isEmpty {
            bluetoothDeviceName = d
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: work)
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
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            isLyricsEnabled.toggle()
        }
        if isLyricsEnabled {
            loadLyrics()
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
        let target = position + 0.35 // slight perceptual lead
        let idx = lyricsLines.lastIndex(where: { $0.timestamp <= target })
        if currentLyricIndex != idx {
            currentLyricIndex = idx
        }
    }
    
    // MARK: - On-Demand Waveform Animation (Zero CPU Idle)
    private func updateWaveformTimer() {
        if isPlaying {
            if waveformCancellable == nil {
                waveformCancellable = Timer.publish(every: 0.14, on: .main, in: .common)
                    .autoconnect()
                    .sink { [weak self] _ in
                        guard let self = self, self.isPlaying else { return }
                        withAnimation(.easeInOut(duration: 0.13)) {
                            self.waveHeights = (0..<7).map { _ in CGFloat.random(in: 0.25...1.0) }
                        }
                    }
            }
        } else {
            waveformCancellable?.cancel()
            waveformCancellable = nil
            self.waveHeights = Array(repeating: 0.25, count: 7)
        }
    }
    
    // MARK: - Live Second-by-Second Playback Ticker (Zero CPU Idle when Paused)
    private func updatePlaybackTicker() {
        if isPlaying {
            if playbackTickerCancellable == nil {
                playbackTickerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
                    .autoconnect()
                    .sink { [weak self] _ in
                        guard let self = self, self.isPlaying else { return }
                        if self.totalDurationSeconds.isFinite && !self.totalDurationSeconds.isNaN && self.totalDurationSeconds > 0 && self.currentPositionSeconds < self.totalDurationSeconds {
                            self.currentPositionSeconds += 1.0
                            let dur = max(0.1, self.totalDurationSeconds)
                            self.playbackProgress = max(0, min(1.0, self.currentPositionSeconds / dur))
                            self.currentTime = self.formatTime(self.safeSeconds(self.currentPositionSeconds))
                            let rem = max(0, dur - self.currentPositionSeconds)
                            self.remainingTime = "-\(self.formatTime(self.safeSeconds(rem)))"
                            self.updateActiveLyricIndex(for: self.currentPositionSeconds)
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
    
    // MARK: - File Shelf Controls
    public func addFiles(_ urls: [URL]) {
        for url in urls {
            if !shelfFiles.contains(url) {
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
    
    private func safeSeconds(_ val: Double) -> Int {
        guard val.isFinite, !val.isNaN, val >= 0 else { return 0 }
        if val > 86400 * 365 { return 0 } // Clamp to reasonable duration
        return Int(val)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let m = s / 60
        let sec = s % 60
        return String(format: "%d:%02d", m, sec)
    }
}
