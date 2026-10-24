import AppKit
import SwiftUI

// MARK: - Hosting View Cerdas: Klik di luar kapsul tembus ke tab browser / desktop
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
        
        // Active pill & card dimensions
        let capsuleWidth: CGFloat = {
            if state.isShowingVolumeHUD { return 250 }
            if state.mode == .expanded { return 395 }
            return state.isPlaying ? 205 : (state.isTimerRunning ? 180 : 160)
        }()
        
        let capsuleHeight: CGFloat = {
            if state.isShowingVolumeHUD { return 36 }
            if state.mode == .expanded { return 215 }
            return 34
        }()
        
        let capsuleX = (bounds.width - capsuleWidth) / 2
        let capsuleY = bounds.height - 4 - capsuleHeight
        let activeRect = NSRect(x: capsuleX - 4, y: capsuleY - 4, width: capsuleWidth + 8, height: capsuleHeight + 8)
        
        if activeRect.contains(point) {
            return super.hitTest(point)
        }
        
        // Jika kursor berada di area transparan, kembalikan nil agar klik tembus
        // dan tidak menghalangi tab browser/tombol apa pun di belakangnya!
        return nil
    }
}

public class DynamicIslandPanel: NSPanel {
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    
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
    }
    
    // MARK: - Izinkan Panel Menerima Fokus Keyboard (PENTING untuk Mengetik di Kolom Notes!)
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return true
    }
    
    // MARK: - Saran 1: Deteksi Klik di Luar untuk Menutup saat Menu Terbuka
    public func startClickOutsideMonitoring(state: IslandState) {
        let checkClickOutside: (NSEvent) -> Void = { [weak self] _ in
            guard state.mode == .expanded else { return }
            let mouseLoc = NSEvent.mouseLocation
            
            guard let screen = self?.screen ?? NSScreen.main else { return }
            let capsuleWidth: CGFloat = 395
            let capsuleHeight: CGFloat = 215
            let capsuleX = screen.frame.midX - (capsuleWidth / 2)
            let capsuleY = screen.frame.maxY - capsuleHeight - 8
            let capsuleRect = CGRect(x: capsuleX, y: capsuleY, width: capsuleWidth, height: capsuleHeight)
            
            // Jika klik berada di luar kartu, langsung minimize
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
        // Menggantung dengan margin ~8pt di bawah menu bar (Floating Pill)
        let yPos = screenRect.maxY - panelHeight - 8
        
        self.setFrame(NSRect(x: xPos, y: yPos, width: panelWidth, height: panelHeight), display: true)
    }
}
