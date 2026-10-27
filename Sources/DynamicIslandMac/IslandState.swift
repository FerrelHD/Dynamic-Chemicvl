import Foundation
import Combine
import SwiftUI
import AppKit

public enum IslandMode: Equatable {
    case compact
    case expanded
}

public enum IslandTab: String, CaseIterable {
    case control = "Controls"
    case music = "Music"
    case notes = "Reminders"
    case shelf = "Shelf"
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
    @Published public var mode: IslandMode = .compact
    @Published public var activeTab: IslandTab = .control
    
    // Hover Peek Mode
    @Published public var isHoverPeekEnabled: Bool = true
    @Published public var isHoverRevealed: Bool = false
    private let hoverPeekStorageKey = "DynamicIsland_HoverPeekEnabled"
    
    public var isIslandVisible: Bool {
        if !isHoverPeekEnabled { return true }
        if mode == .expanded { return true }
        if isShowingVolumeHUD || isShowingBatteryHUD || isShowingCapsLockHUD { return true }
        return isHoverRevealed
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
    @Published public var artworkImage: NSImage? = nil
    
    // Waveform simulation
    @Published public var waveHeights: [CGFloat] = [0.2, 0.5, 0.3, 0.7, 0.4, 0.6, 0.3]
    private var waveformCancellable: AnyCancellable?
    
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
        
        if let vol = AudioService.shared.getSystemVolume() {
            self.currentVolume = vol
        }
        
        refreshControlStatus()
        
        // Monitoring Media Universal otomatis
        MediaService.shared.startMonitoring { [weak self] info in
            guard let self = self else { return }
            let wasPlaying = self.isPlaying
            self.isPlaying = info.isPlaying
            self.trackTitle = info.title
            self.artistName = info.artist
            self.albumName = info.album
            
            if self.isPlaying != wasPlaying {
                self.updateWaveformTimer()
            }
            
            if let artData = info.artworkData {
                self.artworkImage = NSImage(data: artData)
            } else {
                self.artworkImage = nil
            }
            
            if info.duration > 0 {
                self.playbackProgress = max(0, min(1.0, info.position / info.duration))
                self.currentTime = self.formatTime(Int(info.position))
                self.totalDuration = self.formatTime(Int(info.duration))
            } else {
                self.playbackProgress = 0
                self.currentTime = "0:00"
                self.totalDuration = "0:00"
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
        
        BatteryService.shared.startMonitoring { [weak self] status, powerChanged in
            guard let self = self else { return }
            self.batteryLevel = status.level
            self.isBatteryCharging = status.isCharging
            self.isPowerPlugged = status.isPlugged
            
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
    
    // MARK: - Saran 1: Toggle Expand & Minimize
    public func toggleExpand() {
        if isShowingVolumeHUD {
            isShowingVolumeHUD = false
        }
        refreshControlStatus()
        
        let willExpand = (mode == .compact)
        withAnimation(.spring(response: 0.34, dampingFraction: 0.74)) {
            mode = willExpand ? .expanded : .compact
        }
    }
    
    public func minimize() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
            self.mode = .compact
        }
    }
    
    // MARK: - Hover Peek Mode Action
    public func toggleHoverPeek() {
        withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
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
        }
    }
    
    public func toggleBluetooth() {
        SystemControlService.shared.toggleBluetooth(currentlyEnabled: isBluetoothOn) { [weak self] newState in
            self?.isBluetoothOn = newState
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
        
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            isShowingVolumeHUD = true
        }
        
        let work = DispatchWorkItem { [weak self] in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                self?.isShowingVolumeHUD = false
            }
        }
        volumeHUDWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }
    
    // MARK: - Battery & MagSafe HUD Trigger
    public func triggerBatteryHUD() {
        guard mode != .expanded else { return }
        batteryHUDWorkItem?.cancel()
        
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            isShowingBatteryHUD = true
        }
        
        let work = DispatchWorkItem { [weak self] in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                self?.isShowingBatteryHUD = false
            }
        }
        batteryHUDWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
    }
    
    // MARK: - Caps Lock HUD Trigger
    public func triggerCapsLockHUD(isOn: Bool) {
        guard mode != .expanded else { return }
        isCapsLockOn = isOn
        capsLockHUDWorkItem?.cancel()
        
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            isShowingCapsLockHUD = true
        }
        
        let work = DispatchWorkItem { [weak self] in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
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
    
    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
