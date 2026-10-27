import AppKit
import SwiftUI
import Combine

// MARK: - Responsive Hosting View
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
        // Since the window frame is physically tight to the visible island,
        // any point inside bounds is interactive.
        guard self.bounds.contains(point) else { return nil }
        return super.hitTest(point)
    }
}

public class DynamicIslandPanel: NSPanel {
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var mouseMoveMonitor: Any?
    private var localMouseMoveMonitor: Any?
    private var hideDebounceTimer: Timer?
    private var screenChangeObserver: Any?
    private var spaceChangeObserver: Any?
    private var appActivateObserver: Any?
    private var fullScreenPollTimer: Timer?
    private var stateCancellable: AnyCancellable?
    
    public init() {
        let initialDims = IslandState.shared.currentDimensions
        let initialRect = NSRect(x: 0, y: 0, width: initialDims.width, height: initialDims.height)
        
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
        
        setupFullScreenObservers()
        updateFrame(animated: false)
        
        // Listen to IslandState changes to dynamically resize the physical NSWindow
        stateCancellable = IslandState.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateFrame(animated: true)
                }
            }
        
        // Responsive screen change tracking (multi-monitor, resolution changes)
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkFullScreenState()
            self?.repositionToTopCenter()
        }
    }
    
    // MARK: - Automatic Fullscreen Detection (Auto-Hide in Fullscreen, Auto-Standby on Desktop)
    private func setupFullScreenObservers() {
        let center = NSWorkspace.shared.notificationCenter
        spaceChangeObserver = center.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkFullScreenState()
        }
        
        appActivateObserver = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkFullScreenState()
        }
        
        // Lightweight polling timer (every 1.0s) to catch any active fullscreen window
        fullScreenPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkFullScreenState()
        }
        
        checkFullScreenState()
    }
    
    private func checkFullScreenState() {
        guard let screen = self.screen ?? NSScreen.main else { return }
        let screenW = screen.frame.width
        let screenH = screen.frame.height
        
        // 1. Direct window server inspection of the frontmost app's window bounds
        var isFullScreen = false
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            // Ignore Finder desktop itself so Desktop space is never flagged as fullscreen
            if frontApp.bundleIdentifier != "com.apple.finder" {
                let frontPID = frontApp.processIdentifier
                let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
                if let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] {
                    var unionRect = CGRect.null
                    for win in list {
                        if let pid = win[kCGWindowOwnerPID as String] as? pid_t, pid == frontPID,
                           let layer = win[kCGWindowLayer as String] as? Int, layer == 0,
                           let boundsDict = win[kCGWindowBounds as String] as? [String: Any],
                           let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) {
                            unionRect = unionRect.union(rect)
                        }
                    }
                    // If frontmost app has windows covering the full screen, it is fullscreen!
                    if unionRect.width >= (screenW - 2) && unionRect.height >= (screenH - 2) && unionRect.minY <= 1 {
                        isFullScreen = true
                    }
                }
            }
        }
        
        // 2. Secondary fallback: check if menu bar is hidden on main screen
        if !isFullScreen {
            if screen.visibleFrame.maxY >= (screen.frame.maxY - 2) {
                isFullScreen = true
            }
        }
        
        if IslandState.shared.isFullScreenAppActive != isFullScreen {
            DispatchQueue.main.async { [weak self] in
                withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                    IslandState.shared.isFullScreenAppActive = isFullScreen
                }
                self?.updateFrame(animated: false)
            }
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
            let dims = state.currentDimensions
            let screenRect = screen.frame
            let midX = screenRect.midX
            let topY = screenRect.maxY
            
            let insideX = abs(mouseLoc.x - midX) <= (dims.width / 2)
            let insideY = (mouseLoc.y >= topY - dims.height) && (mouseLoc.y <= topY)
            
            if !insideX || !insideY {
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
                self?.hideDebounceTimer?.invalidate()
                self?.hideDebounceTimer = nil
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
            
            if inTriggerZone || (state.isHoverRevealed && inActiveZone) {
                self?.hideDebounceTimer?.invalidate()
                self?.hideDebounceTimer = nil
                
                if !state.isHoverRevealed {
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                            state.isHoverRevealed = true
                        }
                    }
                }
            } else if state.isHoverRevealed {
                if self?.hideDebounceTimer == nil {
                    self?.hideDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.30, repeats: false) { [weak self] _ in
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
        }
        
        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: checkHover)
        localMouseMoveMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { event in
            checkHover(event)
            return event
        }
    }
    
    public func updateFrame(animated: Bool = true) {
        guard let screen = self.screen ?? NSScreen.main else { return }
        
        let screenRect = screen.frame
        let dims = IslandState.shared.currentDimensions
        
        let panelWidth = dims.width
        let panelHeight = dims.height
        
        // Exact mathematical dead-center alignment across all screen resolutions
        let xPos = floor(screenRect.minX + ((screenRect.width - panelWidth) / 2.0))
        let yPos = screenRect.maxY - panelHeight
        let newFrame = NSRect(x: xPos, y: yPos, width: panelWidth, height: panelHeight)
        
        guard self.frame != newFrame else { return }
        
        // Direct setFrame guarantees rock-solid dead-center accuracy without AppKit animator drift
        self.setFrame(newFrame, display: true)
    }
    
    public func repositionToTopCenter() {
        updateFrame(animated: false)
    }
}
