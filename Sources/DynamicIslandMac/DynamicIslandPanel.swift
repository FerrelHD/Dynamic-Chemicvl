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
    
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    public override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = self.convert(point, from: self.superview)
        guard self.bounds.contains(localPoint) else { return nil }
        
        let dims = state.currentDimensions
        let notchX = (self.bounds.width - dims.width) / 2.0
        let notchRect = CGRect(x: notchX, y: 0, width: dims.width, height: dims.height)
        
        // If click is outside the active notch frame, pass through immediately
        guard notchRect.contains(localPoint) else {
            return nil
        }
        
        // Check if inside the curved notch path (including concave ear fillets)
        let earRadius: CGFloat = (state.mode == .expanded) ? 11 : ((state.isShowingBatteryHUD || state.isShowingWifiHUD || state.isShowingBluetoothHUD || state.isShowingVolumeHUD) ? 8 : 6)
        let bottomRadius: CGFloat = (state.mode == .expanded) ? 24 : ((state.isShowingBatteryHUD || state.isShowingWifiHUD || state.isShowingBluetoothHUD || state.isShowingVolumeHUD) ? 18 : 14)
        
        let pointInNotch = CGPoint(x: localPoint.x - notchX, y: localPoint.y)
        let localNotchRect = CGRect(origin: .zero, size: CGSize(width: dims.width, height: dims.height))
        let notchPath = NotchShape(earRadius: earRadius, bottomRadius: bottomRadius).path(in: localNotchRect)
        
        // If click is in the transparent cutout corners outside the notch curve, pass through
        guard notchPath.contains(pointInNotch) else {
            return nil
        }
        
        return super.hitTest(point) ?? self
    }
    
    public override var fittingSize: NSSize {
        let dims = state.currentDimensions
        return NSSize(width: dims.width, height: dims.height)
    }
    
    public override var intrinsicContentSize: NSSize {
        let dims = state.currentDimensions
        return NSSize(width: dims.width, height: dims.height)
    }
}

public class DynamicIslandPanel: NSPanel {
    private var stateCancellable: AnyCancellable?
    private var collapseWorkItem: DispatchWorkItem?
    
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var mouseMoveMonitor: Any?
    private var localMouseMoveMonitor: Any?
    private var hideDebounceTimer: Timer?
    private var screenChangeObserver: Any?
    private var spaceChangeObserver: Any?
    private var appActivateObserver: Any?
    private var fullScreenPollTimer: Timer?
    
    public init() {
        let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let dims = IslandState.shared.currentDimensions
        let canvasPadding: CGFloat = 32.0
        let canvasBottomPadding: CGFloat = 8.0
        let targetW: CGFloat = dims.width + canvasPadding
        let targetH: CGFloat = dims.height + canvasBottomPadding
        let xPos = floor(screenRect.minX + ((screenRect.width - targetW) / 2.0))
        let yPos = screenRect.maxY - targetH
        let initialRect = NSRect(x: xPos, y: yPos, width: targetW, height: targetH)
        
        super.init(
            contentRect: initialRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.minSize = NSSize(width: 48, height: 4)
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 3)
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
        self.becomesKeyOnlyIfNeeded = true
        
        setupFullScreenObservers()
        setupStateObserver()
        IslandState.shared.onModeChangedToExpanded = { [weak self] in
            self?.expandWindowImmediately()
        }
        updateWindowFrameForCurrentState()
        
        // Responsive screen change tracking (multi-monitor, resolution changes)
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkFullScreenState()
            self?.updateWindowFrameForCurrentState()
        }
    }
    
    private func setupStateObserver() {
        stateCancellable = IslandState.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateWindowFrameForCurrentState()
                }
            }
    }
    
    public func expandWindowImmediately() {
        guard let screen = self.screen ?? NSScreen.main else { return }
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        let screenRect = screen.frame
        let dims = IslandState.shared.currentDimensions
        let canvasPadding: CGFloat = 32.0
        let canvasBottomPadding: CGFloat = 8.0
        let targetW: CGFloat = dims.width + canvasPadding
        let targetH: CGFloat = dims.height + canvasBottomPadding
        let targetX = floor(screenRect.minX + ((screenRect.width - targetW) / 2.0))
        let targetY = screenRect.maxY - targetH
        let targetFrame = NSRect(x: targetX, y: targetY, width: targetW, height: targetH)
        
        if self.frame != targetFrame {
            super.setFrame(targetFrame, display: false)
        }
    }
    
    public func updateWindowFrameForCurrentState() {
        let state = IslandState.shared
        let dims = state.currentDimensions
        
        if state.mode == .expanded {
            expandWindowImmediately()
        } else {
            // Compact mode or HUD:
            // If the window was previously expanded, wait 0.35s for SwiftUI's spring animation to finish
            // cleanly before shrinking the window frame back to compact size, freeing Chrome completely!
            if self.frame.height > dims.height + 10 {
                if collapseWorkItem == nil {
                    let workItem = DispatchWorkItem { [weak self] in
                        guard let self = self else { return }
                        self.collapseWorkItem = nil
                        guard IslandState.shared.mode == .compact else { return }
                        self.applyCompactFrame()
                    }
                    collapseWorkItem = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
                }
            } else {
                collapseWorkItem?.cancel()
                collapseWorkItem = nil
                applyCompactFrame()
            }
        }
    }
    
    private func applyCompactFrame() {
        guard let screen = self.screen ?? NSScreen.main else { return }
        let screenRect = screen.frame
        let dims = IslandState.shared.currentDimensions
        let canvasPadding: CGFloat = 32.0
        let canvasBottomPadding: CGFloat = 8.0
        let targetW = dims.width + canvasPadding
        let targetH = dims.height + canvasBottomPadding
        let targetX = floor(screenRect.minX + ((screenRect.width - targetW) / 2.0))
        let targetY = screenRect.maxY - targetH
        let targetFrame = NSRect(x: targetX, y: targetY, width: targetW, height: targetH)
        
        if self.frame != targetFrame {
            super.setFrame(targetFrame, display: true)
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
    
    // MARK: - Non-Activating Overlay (Keyboard Focus Only When Expanded for Notes)
    public override var canBecomeKey: Bool {
        return IslandState.shared.mode == .expanded
    }
    
    public override var canBecomeMain: Bool {
        return IslandState.shared.mode == .expanded
    }
    
    // MARK: - Click-Outside Detection to Minimize
    public func startClickOutsideMonitoring(state: IslandState) {
        let checkClickOutside: (NSEvent) -> Void = { [weak self] event in
            guard state.mode == .expanded else { return }
            
            // Shelf Pinned Mode: While on Shelf tab, keep open so user can click and drag files from Finder
            if state.activeTab == .shelf {
                return
            }
            
            // For global monitor events, locationInWindow gives the actual screen coordinate of the click
            let clickLoc = event.locationInWindow
            
            guard let screen = self?.screen ?? NSScreen.main else { return }
            let dims = state.currentDimensions
            let screenRect = screen.frame
            let midX = screenRect.midX
            let topY = screenRect.maxY
            
            let insideX = abs(clickLoc.x - midX) <= (dims.width / 2)
            let insideY = (clickLoc.y >= topY - dims.height) && (clickLoc.y <= topY)
            
            if !insideX || !insideY {
                DispatchQueue.main.async {
                    state.minimize()
                }
            }
        }
        
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: checkClickOutside)
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
                        withAnimation(.easeInOut(duration: 0.20)) {
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
                                withAnimation(.easeInOut(duration: 0.20)) {
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
        updateWindowFrameForCurrentState()
    }
    
    public func repositionToTopCenter() {
        updateWindowFrameForCurrentState()
    }
}
