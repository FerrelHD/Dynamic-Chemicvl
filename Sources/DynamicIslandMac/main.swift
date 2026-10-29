import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var panel: DynamicIslandPanel?
    var statusItem: NSStatusItem?
    private var launchAtLoginMenuItem: NSMenuItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        let islandPanel = DynamicIslandPanel()
        let hostingView = IslandHostingView(rootView: DynamicIslandView(state: .shared), state: .shared)
        
        islandPanel.contentView = hostingView
        islandPanel.orderFrontRegardless()
        islandPanel.startClickOutsideMonitoring(state: .shared)
        islandPanel.startHoverPeekMonitoring(state: .shared)
        self.panel = islandPanel
        
        // Setup Menu Bar Tray Item
        setupStatusItem()
        
        // Register global keyboard shortcut (Option + Space)
        HotKeyService.shared.registerDefaultHotKey {
            IslandState.shared.toggleExpand()
        }
        
        // Start listening to macOS chat notifications from Dock badges
        NotificationListenerService.shared.startMonitoring()
        
        print("🏝️ Native Dynamic Island Active (iOS Design & Full English)")
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            let img = (NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "NotchFlow") ??
                       NSImage(systemSymbolName: "capsule.portrait.fill", accessibilityDescription: "NotchFlow"))?
                .withSymbolConfiguration(config)
            
            if let icon = img {
                icon.isTemplate = true
                button.image = icon
            } else {
                button.title = "🏝️"
            }
            button.toolTip = "NotchFlow — Dynamic Island for Mac"
        }
        
        let menu = NSMenu()
        menu.delegate = self
        
        let toggleItem = NSMenuItem(title: "Toggle Dynamic Island", action: #selector(toggleIslandAction), keyEquivalent: " ")
        toggleItem.keyEquivalentModifierMask = [.option]
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        let settingsItem = NSMenuItem(title: "Settings & Customization...", action: #selector(openSettingsAction), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLoginAction), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = IslandState.shared.isLaunchAtLoginEnabled ? .on : .off
        self.launchAtLoginMenuItem = launchItem
        menu.addItem(launchItem)
        
        let fdaItem = NSMenuItem(title: "Notification Center Permissions...", action: #selector(openFDAPreferencesAction), keyEquivalent: "")
        fdaItem.target = self
        menu.addItem(fdaItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let websiteItem = NSMenuItem(title: "Visit Website & Updates...", action: #selector(openWebsiteAction), keyEquivalent: "")
        websiteItem.target = self
        menu.addItem(websiteItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit NotchFlow", action: #selector(quitAppAction), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    // NSMenuDelegate: Refresh state before menu opens
    func menuWillOpen(_ menu: NSMenu) {
        IslandState.shared.checkLaunchAtLoginStatus()
        launchAtLoginMenuItem?.state = IslandState.shared.isLaunchAtLoginEnabled ? .on : .off
    }
    
    @objc private func toggleIslandAction() {
        IslandState.shared.toggleExpand()
    }
    
    @objc private func openSettingsAction() {
        let state = IslandState.shared
        state.isHoverRevealed = true
        state.isShowingSettings = true
        if state.mode != .expanded {
            state.onModeChangedToExpanded?()
            withAnimation(state.activeSpringAnimation) {
                state.mode = .expanded
            }
        }
        state.triggerHaptic(.generic)
    }
    
    @objc private func toggleLaunchAtLoginAction() {
        IslandState.shared.toggleLaunchAtLogin()
        launchAtLoginMenuItem?.state = IslandState.shared.isLaunchAtLoginEnabled ? .on : .off
    }
    
    @objc private func openFDAPreferencesAction() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func openWebsiteAction() {
        if let url = URL(string: "https://github.com/FerrelHD/Dynamic-Chemicvl") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func toggleVisibilityAction() {
        guard let panel = panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }
    
    @objc private func quitAppAction() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
