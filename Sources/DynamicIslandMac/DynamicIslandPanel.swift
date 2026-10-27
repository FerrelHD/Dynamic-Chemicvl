import AppKit
import SwiftUI

// MARK: - Responsive Hosting View: Click pass-through for transparent areas
public class IslandHostingView<Content: View>: NSHostingView<Content> {
    private let state: IslandState
    
    public init(rootView: Content, state: IslandState = .shared) {
        self.state = state
        super.init(rootView: rootView)
    }
    
    @MainActor required public init(rootView: Content) {
        self.state = IslandState.shared
        super.init(rootView: rootView)
    }
    
    @MainActor required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func hitTest(_ point: NSPoint) -> NSView? {
        let bounds = self.bounds
        
        // When tucked away, pass 100% of clicks through EXCEPT on the tiny micro-notch handle!
        if !state.isIslandVisible {
            let handleWidth: CGFloat = 52
            let handleHeight: CGFloat = 8
            let handleX = (bounds.width - handleWidth) / 2
            let handleY = bounds.height - handleHeight
            let handleRect = NSRect(x: handleX - 4, y: handleY - 2, width: handleWidth + 8, height: handleHeight + 4)
            if handleRect.contains(point) {
                return super.hitTest(point)
            }
            return nil
        }
        
        // Dynamic adaptive dimensions matching DynamicIslandView
        let capsuleWidth: CGFloat = {
            if state.isShowingVolumeHUD { return 260 }
            if state.isShowingBatteryHUD { return 350 }
            if state.isShowingCapsLockHUD { return 195 }
            if state.mode == .expanded { return 395 }
            if state.isTimerRunning { return 165 }
            if state.isPlaying {
                let titleLen = CGFloat(state.trackTitle.count)
                return max(195, min(245, 165 + titleLen * 3.0))
            }
            return 136
        }()
        
        let capsuleHeight: CGFloat = {
            if state.isShowingBatteryHUD { return 54 }
            if state.isShowingVolumeHUD || state.isShowingCapsLockHUD { return 36 }
            if state.mode == .expanded {
                switch state.activeTab {
                case .music: return 172
                case .control: return 216
                case .notes: return 196
                case .shelf: return 180
                }
            }
            return 34
        }()
        
        let capsuleX = (bounds.width - capsuleWidth) / 2
        let capsuleY = bounds.height - capsuleHeight
        let activeRect = NSRect(x: capsuleX - 4, y: capsuleY - 2, width: capsuleWidth + 8, height: capsuleHeight + 4)
        
        if activeRect.contains(point) {
            return super.hitTest(point)
        }
        
        // Pass clicks through transparent bounds to background windows (Safari, Chrome, Desktop)
        return nil
    }
}

public class DynamicIslandPanel: NSPanel {
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var mouseMoveMonitor: Any?
    private var localMouseMoveMonitor: Any?
    private var hideDebounceTimer: Timer?
    private var revealDwellTimer: Timer?
    private var screenChangeObserver: Any?
    
    public init() {
        let initialRect = NSRect(x: 0, y: 0, width: 460, height: 260)
        
        super.init(
            contentRect: initialRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovable = false
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false
        self.ignoresMouseEvents = false
        
        repositionToTopCenter()
        
        // Responsive screen change tracking (multi-monitor, resolution changes)
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.repositionToTopCenter()
        }
    }
    
    // MARK: - Non-Activating Overlay (Never Steal Focus from Active Apps like Chrome)
    public override var canBecomeKey: Bool {
        return false
    }
    
    public override var canBecomeMain: Bool {
        return false
    }
    
    // MARK: - Click-Outside Detection to Minimize
    public func startClickOutsideMonitoring(state: IslandState) {
        let checkClickOutside: (NSEvent) -> Void = { [weak self] _ in
            guard state.mode == .expanded else { return }
            let mouseLoc = NSEvent.mouseLocation
            
            guard let screen = self?.screen ?? NSScreen.main else { return }
            let capsuleWidth: CGFloat = 395
            let capsuleHeight: CGFloat = {
                switch state.activeTab {
                case .music: return 172
                case .control: return 216
                case .notes: return 196
                case .shelf: return 180
                }
            }()
            
            let capsuleX = screen.frame.midX - (capsuleWidth / 2)
            let capsuleY = screen.frame.maxY - capsuleHeight
            let capsuleRect = CGRect(x: capsuleX, y: capsuleY, width: capsuleWidth, height: capsuleHeight)
            
            // If click is outside the active card frame, minimize immediately
            if !capsuleRect.contains(mouseLoc) {
                DispatchQueue.main.async {
                    state.minimize()
                }
            }
        }
        
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: checkClickOutside)
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            checkClickOutside(event)
            return event
        }
    }
    
    // MARK: - Smart Hover Peek Detection (Top Bezel Trigger & Dismiss)
    public func startHoverPeekMonitoring(state: IslandState) {
        let checkHover: (NSEvent) -> Void = { [weak self] _ in
            guard state.isHoverPeekEnabled else { return }
            
            if state.mode == .expanded || state.isShowingVolumeHUD || state.isShowingBatteryHUD || state.isShowingCapsLockHUD {
                self?.revealDwellTimer?.invalidate()
                self?.revealDwellTimer = nil
                return
            }
            
            guard let screen = self?.screen ?? NSScreen.main else { return }
            let mouseLoc = NSEvent.mouseLocation
            let screenRect = screen.frame
            let midX = screenRect.midX
            let topY = screenRect.maxY
            
            // Trigger zone: top 14pt of screen in menu bar area
            let inTriggerZone = (mouseLoc.y >= topY - 14) && (abs(mouseLoc.x - midX) <= 135)
            
            // Active zone: keep revealed while cursor is inside or directly surrounding the notch
            let inActiveZone = (mouseLoc.y >= topY - 56) && (abs(mouseLoc.x - midX) <= 160)
            
            if state.isHoverRevealed {
                self?.revealDwellTimer?.invalidate()
                self?.revealDwellTimer = nil
                
                if inActiveZone {
                    self?.hideDebounceTimer?.invalidate()
                    self?.hideDebounceTimer = nil
                } else {
                    if self?.hideDebounceTimer == nil {
                        self?.hideDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
                            self?.hideDebounceTimer = nil
                            let currentLoc = NSEvent.mouseLocation
                            let stillInZone = (currentLoc.y >= topY - 56) && (abs(currentLoc.x - midX) <= 160)
                            if !stillInZone && state.mode != .expanded {
                                DispatchQueue.main.async {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.80)) {
                                        state.isHoverRevealed = false
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                self?.hideDebounceTimer?.invalidate()
                self?.hideDebounceTimer = nil
                
                if inTriggerZone {
                    if self?.revealDwellTimer == nil {
                        self?.revealDwellTimer = Timer.scheduledTimer(withTimeInterval: 0.20, repeats: false) { [weak self] _ in
                            self?.revealDwellTimer = nil
                            let currentLoc = NSEvent.mouseLocation
                            let stillInTrigger = (currentLoc.y >= topY - 16) && (abs(currentLoc.x - midX) <= 140)
                            if stillInTrigger && !state.isHoverRevealed && state.mode != .expanded {
                                DispatchQueue.main.async {
                                    withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                                        state.isHoverRevealed = true
                                    }
                                }
                            }
                        }
                    }
                } else {
                    self?.revealDwellTimer?.invalidate()
                    self?.revealDwellTimer = nil
                }
            }
        }
        
        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: checkHover)
        localMouseMoveMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { event in
            checkHover(event)
            return event
        }
    }
    
    public func repositionToTopCenter() {
        guard let screen = NSScreen.main else { return }
        
        let screenRect = screen.frame
        let panelWidth: CGFloat = 460
        let panelHeight: CGFloat = 260
        
        let xPos = floor(screenRect.midX - (panelWidth / 2))
        // Flush with top bezel of screen: 0pt margin!
        let yPos = screenRect.maxY - panelHeight
        
        self.setFrame(NSRect(x: xPos, y: yPos, width: panelWidth, height: panelHeight), display: true)
    }
}
