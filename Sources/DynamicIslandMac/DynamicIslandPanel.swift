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
        guard state.isIslandVisible else { return nil }
        
        let localPoint = self.convert(point, from: self.superview)
        guard self.bounds.contains(localPoint) else { return nil }
        
        let dims = state.currentDimensions
        let notchX = (self.bounds.width - dims.width) / 2.0
        let notchY = self.isFlipped ? 0 : (self.bounds.height - dims.height)
        let notchRect = CGRect(x: notchX, y: notchY, width: dims.width, height: dims.height)
        
        // If click is outside the active notch frame, pass through immediately
        guard notchRect.contains(localPoint) else {
            return nil
        }
        
        // Check if inside the curved notch path (including concave ear fillets)
        let earRadius: CGFloat = (state.activeChatNotification != nil || state.activeCallNotification != nil || state.activeAirDropNotification != nil) ? 13 : ((state.mode == .expanded) ? 15 : ((state.isShowingBatteryHUD || state.isShowingWifiHUD || state.isShowingBluetoothHUD || state.isShowingVolumeHUD) ? 11 : 9))
        let bottomRadius: CGFloat = (state.activeChatNotification != nil || state.activeCallNotification != nil || state.activeAirDropNotification != nil) ? 22 : ((state.mode == .expanded) ? 24 : ((state.isShowingBatteryHUD || state.isShowingWifiHUD || state.isShowingBluetoothHUD || state.isShowingVolumeHUD) ? 14 : 14))
        
        let pointInNotch = CGPoint(x: localPoint.x - notchX, y: localPoint.y - notchY)
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
    
    // MARK: - 2-Finger Trackpad Horizontal Swipe Tab Navigation (1-Swipe 1-Tab Paging Lock)
    private var accumulatedScrollDeltaX: CGFloat = 0.0
    private var hasSwitchedTabInCurrentGesture: Bool = false
    
    public override func scrollWheel(with event: NSEvent) {
        guard state.mode == .expanded else {
            super.scrollWheel(with: event)
            return
        }
        
        // Reset gesture lock when a new physical touch begins
        if event.phase == .began {
            hasSwitchedTabInCurrentGesture = false
            accumulatedScrollDeltaX = 0
        } else if event.phase == .ended || event.phase == .cancelled {
            hasSwitchedTabInCurrentGesture = false
            accumulatedScrollDeltaX = 0
            return
        }
        
        // Completely ignore momentum scrolling so inertia cannot overshoot tabs
        if !event.momentumPhase.isEmpty {
            return
        }
        
        // If we already switched a tab in this swipe gesture, lock until next physical gesture
        if hasSwitchedTabInCurrentGesture {
            return
        }
        
        let dx = event.scrollingDeltaX
        let dy = event.scrollingDeltaY
        
        // Detect dominant horizontal trackpad 2-finger swipe
        if abs(dx) > abs(dy) && abs(dx) > 1.2 {
            accumulatedScrollDeltaX += dx
            let threshold: CGFloat = 28.0
            
            if accumulatedScrollDeltaX > threshold {
                hasSwitchedTabInCurrentGesture = true
                accumulatedScrollDeltaX = 0
                DispatchQueue.main.async {
                    self.state.previousTab()
                }
                return
            } else if accumulatedScrollDeltaX < -threshold {
                hasSwitchedTabInCurrentGesture = true
                accumulatedScrollDeltaX = 0
                DispatchQueue.main.async {
                    self.state.nextTab()
                }
                return
            }
            return
        }
        
        super.scrollWheel(with: event)
    }
}

public class DynamicIslandPanel: NSPanel {
    public static let stableCanvasWidth: CGFloat = 752.0
    
    private var stateCancellable: AnyCancellable?
    private var collapseWorkItem: DispatchWorkItem?
    
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var mouseMoveMonitor: Any?
    private var localMouseMoveMonitor: Any?
    private var hideDebounceTimer: Timer?
    private var expandedExitTimer: Timer?
    private var hasEnteredExpanded: Bool = false
    private var screenChangeObserver: Any?
    private var spaceChangeObserver: Any?
    private var appActivateObserver: Any?
    private var fullScreenPollTimer: Timer?
    
    public init() {
        let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let state = IslandState.shared
        let dims = state.currentDimensions
        let targetW: CGFloat = dims.width + 24.0
        let targetH: CGFloat = max(dims.height + 10.0, 48.0)
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
        self.appearance = NSAppearance(named: .darkAqua)
        
        setupFullScreenObservers()
        setupStateObserver()
        IslandState.shared.onModeChangedToExpanded = { [weak self] in
            guard let self = self else { return }
            self.expandWindowImmediately()
            if let screen = self.screen ?? NSScreen.main {
                let mouseLoc = NSEvent.mouseLocation
                let screenRect = screen.frame
                let midX = screenRect.midX
                let topY = screenRect.maxY
                let dims = IslandState.shared.currentDimensions
                let insideX = abs(mouseLoc.x - midX) <= (dims.width / 2.0 + 8.0)
                let insideY = (mouseLoc.y >= topY - dims.height - 8.0) && (mouseLoc.y <= topY + 2.0)
                self.hasEnteredExpanded = (insideX && insideY)
            }
        }
        IslandState.shared.onHoverRevealed = { [weak self] in
            self?.applyRevealedCompactFrame()
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
    
    public override func fieldEditor(_ createFlag: Bool, for aObject: Any?) -> NSText? {
        let editor = super.fieldEditor(createFlag, for: aObject)
        if let tv = editor as? NSTextView {
            tv.insertionPointColor = .white
            tv.appearance = NSAppearance(named: .darkAqua)
        }
        return editor
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
        let targetW: CGFloat = DynamicIslandPanel.stableCanvasWidth
        let targetH: CGFloat = 296.0
        let targetX = floor(screenRect.minX + ((screenRect.width - targetW) / 2.0))
        let targetY = screenRect.maxY - targetH
        let targetFrame = NSRect(x: targetX, y: targetY, width: targetW, height: targetH)
        
        self.ignoresMouseEvents = false
        
        if self.frame != targetFrame {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.setFrame(targetFrame, display: false)
            CATransaction.commit()
        }
    }
    
    public func updateWindowFrameForCurrentState() {
        let state = IslandState.shared
        
        // Ensure the physical NSPanel never blocks underlying window clicks when hidden in fullscreen
        if !state.isIslandVisible {
            self.ignoresMouseEvents = true
            return
        }
        
        if state.mode == .expanded {
            expandWindowImmediately()
        } else {
            let isTallNotification = (state.activeChatNotification != nil || state.activeCallNotification != nil || state.activeAirDropNotification != nil)
            
            if isTallNotification {
                collapseWorkItem?.cancel()
                collapseWorkItem = nil
                applyCompactFrame()
            } else if self.frame.height > 60.0 || self.frame.width > 450.0 {
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
    
    public func applyRevealedCompactFrame() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        
        guard let screen = self.screen ?? NSScreen.main else { return }
        let state = IslandState.shared
        let dims = state.currentDimensions
        let screenRect = screen.frame
        let targetW: CGFloat = dims.width + 24.0
        let targetH: CGFloat = max(dims.height + 10.0, 48.0)
        let targetX = floor(screenRect.minX + ((screenRect.width - targetW) / 2.0))
        let targetY = screenRect.maxY - targetH
        let targetFrame = NSRect(x: targetX, y: targetY, width: targetW, height: targetH)
        
        if self.frame != targetFrame {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            super.setFrame(targetFrame, display: true)
            CATransaction.commit()
        }
    }
    
    private func applyCompactFrame() {
        guard let screen = self.screen ?? NSScreen.main else { return }
        let state = IslandState.shared
        let dims = state.currentDimensions
        let screenRect = screen.frame
        let targetW: CGFloat = dims.width + 24.0
        let targetH: CGFloat = max(dims.height + 10.0, 48.0)
        let targetX = floor(screenRect.minX + ((screenRect.width - targetW) / 2.0))
        let targetY = screenRect.maxY - targetH
        let targetFrame = NSRect(x: targetX, y: targetY, width: targetW, height: targetH)
        
        if self.frame != targetFrame {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            super.setFrame(targetFrame, display: true)
            CATransaction.commit()
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
        
        // Fast-track responsive polling timer (every 0.25s) to catch any active fullscreen window instantly
        fullScreenPollTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
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
                if !isFullScreen {
                    self?.applyRevealedCompactFrame()
                }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.80)) {
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
    
    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "q" {
            NSApp.terminate(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
    
    // MARK: - Click-Outside Detection to Minimize
    public func startClickOutsideMonitoring(state: IslandState) {
        let checkClickOutside: (NSEvent) -> Void = { [weak self] _ in
            guard state.mode == .expanded else { return }
            
            guard let screen = self?.screen ?? NSScreen.main else { return }
            // Use universal absolute screen coordinates (works identically for local & global click monitors)
            let clickLoc = NSEvent.mouseLocation
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
        
        // Global monitor catches clicks far away on other apps / desktop
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: checkClickOutside)
        // Local monitor catches clicks nearby in our transparent window padding
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            checkClickOutside(event)
            return event
        }
    }
    
    // MARK: - Smart Hover Peek Detection (Top Bezel Trigger & Dismiss)
    public func startHoverPeekMonitoring(state: IslandState) {
        let checkHover: (NSEvent) -> Void = { [weak self] _ in
            let state = IslandState.shared
            guard state.isIslandVisible else {
                self?.ignoresMouseEvents = true
                return
            }
            
            guard let screen = self?.screen ?? NSScreen.main else { return }
            let mouseLoc = NSEvent.mouseLocation
            let dims = state.currentDimensions
            let screenRect = screen.frame
            let midX = screenRect.midX
            let topY = screenRect.maxY
            
            let insideX = abs(mouseLoc.x - midX) <= (dims.width / 2.0 + 8.0)
            let insideY = (mouseLoc.y >= topY - dims.height - 8.0) && (mouseLoc.y <= topY + 2.0)
            let isInsideNotch = insideX && insideY
            
            // In expanded mode: manage exit timer and dynamic ignoresMouseEvents
            if state.mode == .expanded {
                self?.ignoresMouseEvents = !isInsideNotch
                self?.hideDebounceTimer?.invalidate()
                self?.hideDebounceTimer = nil
                
                // Click Only Mode: notch stays open until user clicks outside
                if state.dismissMode == .clickOnly {
                    self?.expandedExitTimer?.invalidate()
                    self?.expandedExitTimer = nil
                    return
                }
                
                if isInsideNotch {
                    // Cursor is inside expanded notch
                    self?.hasEnteredExpanded = true
                    self?.expandedExitTimer?.invalidate()
                    self?.expandedExitTimer = nil
                } else if self?.hasEnteredExpanded == true {
                    // Cursor previously entered and now exited expanded notch: trigger 0.15s micro-buffer auto-collapse
                    if self?.expandedExitTimer == nil {
                        self?.expandedExitTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
                            self?.expandedExitTimer = nil
                            let currentLoc = NSEvent.mouseLocation
                            let stillInsideX = abs(currentLoc.x - midX) <= (dims.width / 2.0 + 8.0)
                            let stillInsideY = (currentLoc.y >= topY - dims.height - 8.0) && (currentLoc.y <= topY + 2.0)
                            if (!stillInsideX || !stillInsideY) && state.mode == .expanded && state.dismissMode == .cursorAway {
                                DispatchQueue.main.async {
                                    self?.hasEnteredExpanded = false
                                    state.minimize()
                                }
                            }
                        }
                    }
                }
                return
            }
            
            if state.isShowingVolumeHUD || state.isShowingBatteryHUD || state.isShowingCapsLockHUD {
                self?.hideDebounceTimer?.invalidate()
                self?.hideDebounceTimer = nil
                self?.expandedExitTimer?.invalidate()
                self?.expandedExitTimer = nil
                self?.ignoresMouseEvents = !isInsideNotch
                return
            }
            
            // Dynamic ignoresMouseEvents in compact mode: pass clicks through to menu bar if outside notch
            self?.ignoresMouseEvents = !isInsideNotch
            
            // Trigger zone: top 14pt of screen in menu bar area
            let inTriggerZone = (mouseLoc.y >= topY - 14) && (abs(mouseLoc.x - midX) <= 135)
            
            // Active zone: keep revealed while cursor is inside or directly surrounding the notch
            let inActiveZone = (mouseLoc.y >= topY - 56) && (abs(mouseLoc.x - midX) <= 160)
            
            if inTriggerZone || (state.isHoverRevealed && inActiveZone) {
                self?.hideDebounceTimer?.invalidate()
                self?.hideDebounceTimer = nil
                
                if !state.isHoverRevealed {
                    DispatchQueue.main.async { [weak self] in
                        self?.applyRevealedCompactFrame()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.80)) {
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
                            DispatchQueue.main.async { [weak self] in
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.80)) {
                                    state.isHoverRevealed = false
                                }
                                self?.updateWindowFrameForCurrentState()
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
