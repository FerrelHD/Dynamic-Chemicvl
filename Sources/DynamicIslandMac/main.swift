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
        button.target = self
        button.action = #selector(statusBarButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    
    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            // Right Click: Context Menu
            showStatusContextMenu()
        } else {
            // Left Click: Toggle Island
            IslandState.shared.toggleExpand()
        }
    }
    
    private func showStatusContextMenu() {
        let menu = NSMenu()
        menu.delegate = self
        
        let isExpanded = IslandState.shared.mode == .expanded
        let toggleItem = NSMenuItem(
            title: isExpanded ? "Collapse Dynamic Island" : "Expand Dynamic Island",
            action: #selector(toggleIslandAction),
            keyEquivalent: "d"
        )
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
        
        let isHoverMode = IslandState.shared.isHoverPeekEnabled
        let hoverItem = NSMenuItem(
            title: "Hover Peek Mode",
            action: #selector(toggleHoverPeekAction),
            keyEquivalent: "p"
        )
        hoverItem.state = isHoverMode ? .on : .off
        hoverItem.target = self
        menu.addItem(hoverItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(
            title: "Quit Dynamic Island",
            action: #selector(quitAppAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
    }
    
    func menuDidClose(_ menu: NSMenu) {
        statusItem?.menu = nil
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
    
    @objc private func toggleHoverPeekAction() {
        IslandState.shared.toggleHoverPeek()
    }
    
    @objc private func quitAppAction() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
