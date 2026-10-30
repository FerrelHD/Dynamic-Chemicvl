import AppKit
import SwiftUI

// MARK: - Dedicated Settings Window Manager (Single-Instance Retained Controller)
public class SettingsWindowManager {
    public static let shared = SettingsWindowManager()
    
    private var windowController: NSWindowController?
    
    private init() {}
    
    public func showSettings() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.windowController == nil {
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 840, height: 560),
                    styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                    backing: .buffered,
                    defer: false
                )
                window.center()
                window.title = "NotchFlow Settings"
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.isReleasedWhenClosed = false
                window.minSize = NSSize(width: 740, height: 480)
                window.backgroundColor = NSColor(red: 0.14, green: 0.15, blue: 0.18, alpha: 1.0)
                
                let hostingView = NSHostingView(rootView: SettingsWindowView())
                window.contentView = hostingView
                
                self.windowController = NSWindowController(window: window)
            }
            
            guard let wc = self.windowController, let window = wc.window else { return }
            
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

