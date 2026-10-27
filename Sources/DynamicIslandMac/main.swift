import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var panel: DynamicIslandPanel?
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        let islandPanel = DynamicIslandPanel()
        let hostingView = IslandHostingView(rootView: DynamicIslandView(state: .shared), state: .shared)
        
        islandPanel.contentView = hostingView
        islandPanel.orderFrontRegardless()
        islandPanel.startClickOutsideMonitoring(state: .shared)
        islandPanel.startHoverPeekMonitoring(state: .shared)
        self.panel = islandPanel
        
        setupStatusItem()
        
        // Register global keyboard shortcut (Option + Space)
        HotKeyService.shared.registerDefaultHotKey {
            IslandState.shared.toggleExpand()
        }
        
        print("🏝️ Native Dynamic Island Active (iOS Design & Full English)")
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        
        button.title = "🏝️"
        
        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        let isExpanded = IslandState.shared.mode == .expanded
        let toggleItem = NSMenuItem(
            title: isExpanded ? "Collapse Dynamic Island" : "Expand Dynamic Island",
            action: #selector(toggleIslandAction),
            keyEquivalent: " "
        )
        toggleItem.keyEquivalentModifierMask = [.option]
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        let isVisible = panel?.isVisible == true
        let visibilityItem = NSMenuItem(
            title: isVisible ? "Hide Island" : "Show Island",
            action: #selector(toggleVisibilityAction),
            keyEquivalent: "h"
        )
        visibilityItem.target = self
        menu.addItem(visibilityItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let isSeamless = IslandState.shared.isSeamlessMenuBarEnabled
        let transparentItem = NSMenuItem(
            title: "Transparent Menu Bar (Wallpaper)",
            action: #selector(restoreOriginalWallpaperAction),
            keyEquivalent: "t"
        )
        transparentItem.state = !isSeamless ? .on : .off
        transparentItem.target = self
        menu.addItem(transparentItem)
        
        let seamlessItem = NSMenuItem(
            title: "Solid Black Menu Bar (Match Notch)",
            action: #selector(toggleSeamlessMenuBarAction),
            keyEquivalent: "b"
        )
        seamlessItem.state = isSeamless ? .on : .off
        seamlessItem.target = self
        menu.addItem(seamlessItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(
            title: "Quit Dynamic Island",
            action: #selector(quitAppAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    @objc private func toggleIslandAction() {
        IslandState.shared.toggleExpand()
    }
    
    @objc private func toggleVisibilityAction() {
        guard let panel = panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }
    
    @objc private func toggleSeamlessMenuBarAction() {
        IslandState.shared.toggleSeamlessMenuBar()
    }
    
    @objc private func restoreOriginalWallpaperAction() {
        IslandState.shared.restoreOriginalWallpaper()
    }
    
    @objc private func quitAppAction() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
