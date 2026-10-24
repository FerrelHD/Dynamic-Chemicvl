import AppKit
import SwiftUI

public class DynamicIslandPanel: NSPanel {
    private var clickMonitor: Any?
    private var mouseMonitor: Any?
    private var lastMouseTime: Date = Date()
    private var lastMousePos: CGPoint = .zero
    private var dwellTimer: Timer?
    
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
    }
    
    // MARK: - Solusi 1: Smart Velocity Dodge & Dwell Tracker
    public func startSmartVelocityTracking(state: IslandState) {
        // 1. Deteksi Klik di Luar untuk Menutup saat Expanded
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard state.mode == .expanded else { return }
            let mouseLoc = NSEvent.mouseLocation
            
            guard let screen = self?.screen ?? NSScreen.main else { return }
            let capsuleWidth: CGFloat = 390
            let capsuleHeight: CGFloat = 215
            let capsuleX = screen.frame.midX - (capsuleWidth / 2)
            let capsuleY = screen.frame.maxY - capsuleHeight - 8
            let capsuleRect = CGRect(x: capsuleX, y: capsuleY, width: capsuleWidth, height: capsuleHeight)
            
            if !capsuleRect.contains(mouseLoc) {
                DispatchQueue.main.async {
                    state.minimize()
                    self?.ignoresMouseEvents = false
                }
            }
        }
        
        // 2. Monitor Kecepatan Kursor (Smart Velocity Dodge)
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            guard let self = self else { return }
            let now = Date()
            let pos = NSEvent.mouseLocation
            let dt = now.timeIntervalSince(self.lastMouseTime)
            
            guard dt > 0.005 else { return }
            let dy = pos.y - self.lastMousePos.y
            let speedY = dy / CGFloat(dt) // Kecepatan vertikal ke atas (px/detik)
            
            self.lastMouseTime = now
            self.lastMousePos = pos
            
            guard let screen = self.screen ?? NSScreen.main else { return }
            let islandX = screen.frame.midX
            let islandTop = screen.frame.maxY
            
            // Zona pendekatan: 170 pt kiri-kanan, dan 100 pt di bawah puncak layar
            let isInApproachZone = abs(pos.x - islandX) < 170 && pos.y > (islandTop - 100) && pos.y <= islandTop
            
            if isInApproachZone {
                if state.mode != .expanded {
                    // Kursor melesat cepat ke atas (> 400 px/detik) -> Mau klik tab browser!
                    if speedY > 400 {
                        self.dwellTimer?.invalidate()
                        self.dwellTimer = nil
                        DispatchQueue.main.async {
                            state.triggerDodge()
                            self.ignoresMouseEvents = true // Clicks tembus ke tab browser!
                        }
                    } else if !state.isDodging {
                        // Gerakan santai/berhenti di pulau -> Buka jika bertahan > 150ms
                        if self.dwellTimer == nil {
                            self.dwellTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { _ in
                                DispatchQueue.main.async {
                                    self.ignoresMouseEvents = false
                                    state.expandFromDwell()
                                }
                            }
                        }
                    }
                }
            } else {
                // Keluar dari zona pendekatan
                self.dwellTimer?.invalidate()
                self.dwellTimer = nil
                if state.isDodging {
                    DispatchQueue.main.async {
                        state.recoverFromDodge()
                        self.ignoresMouseEvents = false
                    }
                }
            }
        }
    }
    
    public func repositionToTopCenter() {
        guard let screen = NSScreen.main else { return }
        
        let screenRect = screen.frame
        let panelWidth: CGFloat = 460
        let panelHeight: CGFloat = 260
        
        let xPos = screenRect.midX - (panelWidth / 2)
        let yPos = screenRect.maxY - panelHeight - 8
        
        self.setFrame(NSRect(x: xPos, y: yPos, width: panelWidth, height: panelHeight), display: true)
    }
}
