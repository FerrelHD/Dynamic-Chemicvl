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
        
        // Dynamic adaptive dimensions matching DynamicIslandView
        let capsuleWidth: CGFloat = {
            if state.isShowingVolumeHUD { return 250 }
            if state.mode == .expanded { return 385 }
            if state.isTimerRunning { return 175 }
            if state.isPlaying {
                let titleLen = CGFloat(state.trackTitle.count)
                return max(195, min(235, 165 + titleLen * 3.0))
            }
            return 150
        }()
        
        let capsuleHeight: CGFloat = {
            if state.isShowingVolumeHUD { return 36 }
            if state.mode == .expanded {
                switch state.activeTab {
                case .music: return 172
                case .control: return 192
                case .notes: return 196
                case .shelf: return state.shelfFiles.isEmpty ? 148 : 156
                }
            }
            return 34
        }()
        
        let capsuleX = (bounds.width - capsuleWidth) / 2
        let capsuleY = bounds.height - 4 - capsuleHeight
        let activeRect = NSRect(x: capsuleX - 4, y: capsuleY - 4, width: capsuleWidth + 8, height: capsuleHeight + 8)
        
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
    private var screenChangeObserver: Any?
    
    public init() {
        let initialRect = NSRect(x: 0, y: 0, width: 460, height: 260)
        
        super.init(
            contentRect: initialRect,
            styleMask: [.borderless],
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
    
    // MARK: - Keyboard Focus Support for Reminders & Notes Input
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return true
    }
    
    // MARK: - Click-Outside Detection to Minimize
    public func startClickOutsideMonitoring(state: IslandState) {
        let checkClickOutside: (NSEvent) -> Void = { [weak self] _ in
            guard state.mode == .expanded else { return }
            let mouseLoc = NSEvent.mouseLocation
            
            guard let screen = self?.screen ?? NSScreen.main else { return }
            let capsuleWidth: CGFloat = 385
            let capsuleHeight: CGFloat = {
                switch state.activeTab {
                case .music: return 172
                case .control: return 192
                case .notes: return 196
                case .shelf: return state.shelfFiles.isEmpty ? 148 : 156
                }
            }()
            
            let capsuleX = screen.frame.midX - (capsuleWidth / 2)
            let capsuleY = screen.frame.maxY - capsuleHeight - 8
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
    
    public func repositionToTopCenter() {
        guard let screen = NSScreen.main else { return }
        
        let screenRect = screen.frame
        let panelWidth: CGFloat = 460
        let panelHeight: CGFloat = 260
        
        let xPos = screenRect.midX - (panelWidth / 2)
        // Suspended with ~8pt margin below macOS menu bar
        let yPos = screenRect.maxY - panelHeight - 8
        
        self.setFrame(NSRect(x: xPos, y: yPos, width: panelWidth, height: panelHeight), display: true)
    }
}
