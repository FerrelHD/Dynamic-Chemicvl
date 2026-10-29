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
        
        // Distributed Notification Center for external test triggers and automation
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleTestCallNotification(_:)),
            name: NSNotification.Name("com.ferrel.NotchFlow.testCall"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleTestChatNotification(_:)),
            name: NSNotification.Name("com.ferrel.NotchFlow.testChat"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleTestAcceptCall(_:)),
            name: NSNotification.Name("com.ferrel.NotchFlow.testAcceptCall"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleTestEndCall(_:)),
            name: NSNotification.Name("com.ferrel.NotchFlow.testEndCall"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
        
        // Fast file-based test trigger for automated headless verification (/tmp/notchflow_trigger)
        let triggerTimer = Timer(timeInterval: 0.2, repeats: true) { _ in
            let path = "/tmp/notchflow_trigger"
            if FileManager.default.fileExists(atPath: path),
               let cmd = try? String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) {
                try? FileManager.default.removeItem(atPath: path)
                NSLog("[NotchFlow] 🎯 Received file trigger: %@", cmd)
                if cmd == "call" {
                    let avatar = NSImage(systemSymbolName: "phone.circle.fill", accessibilityDescription: nil)
                    IslandState.shared.triggerCallNotification(callerName: "Sarah Jenkins", subtitle: "WhatsApp Audio...", avatar: avatar)
                } else if cmd == "accept" {
                    IslandState.shared.acceptCall()
                } else if cmd == "end" {
                    IslandState.shared.endCall()
                } else if cmd == "toggle" {
                    IslandState.shared.toggleExpand()
                }
            }
        }
        RunLoop.main.add(triggerTimer, forMode: .common)
        
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
        
        // Test Notifications Submenu
        let testSubmenu = NSMenu()
        let testCallItem = NSMenuItem(title: "Test WhatsApp Call", action: #selector(testCallAction), keyEquivalent: "")
        testCallItem.target = self
        testSubmenu.addItem(testCallItem)
        
        let testChatItem = NSMenuItem(title: "Test WhatsApp Message", action: #selector(testChatAction), keyEquivalent: "")
        testChatItem.target = self
        testSubmenu.addItem(testChatItem)
        
        let testRootItem = NSMenuItem(title: "Test Alerts", action: nil, keyEquivalent: "")
        testRootItem.submenu = testSubmenu
        menu.addItem(testRootItem)
        
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
    
    @objc private func testCallAction() {
        let avatar = NSImage(systemSymbolName: "phone.circle.fill", accessibilityDescription: nil)
        IslandState.shared.triggerCallNotification(
            callerName: "Sarah Jenkins",
            subtitle: "WhatsApp Audio...",
            avatar: avatar
        )
    }
    
    @objc private func handleTestCallNotification(_ notif: Notification) {
        let caller = notif.userInfo?["caller"] as? String ?? "Sarah Jenkins"
        let subtitle = notif.userInfo?["subtitle"] as? String ?? "WhatsApp Audio..."
        NSLog("[NotchFlow] 📞 handleTestCallNotification called with caller: %@, subtitle: %@", caller, subtitle)
        let avatar = NSImage(systemSymbolName: "phone.circle.fill", accessibilityDescription: nil)
        DispatchQueue.main.async {
            IslandState.shared.triggerCallNotification(callerName: caller, subtitle: subtitle, avatar: avatar)
        }
    }
    
    @objc private func handleTestAcceptCall(_ notif: Notification) {
        NSLog("[NotchFlow] 🟢 handleTestAcceptCall called")
        DispatchQueue.main.async {
            IslandState.shared.acceptCall()
        }
    }
    
    @objc private func handleTestEndCall(_ notif: Notification) {
        NSLog("[NotchFlow] 🔴 handleTestEndCall called")
        DispatchQueue.main.async {
            IslandState.shared.endCall()
        }
    }
    
    @objc private func testChatAction() {
        IslandState.shared.triggerChatNotification(
            sender: "Sarah Jenkins",
            message: "Hey! Are we still meeting for coffee today? ☕️",
            app: .whatsapp,
            avatar: ChatApp.whatsapp.appIcon,
            isCustomAvatar: false,
            customBundleIdentifier: "net.whatsapp.WhatsApp"
        )
    }
    
    @objc private func handleTestChatNotification(_ notif: Notification) {
        let sender = notif.userInfo?["sender"] as? String ?? "Sarah Jenkins"
        let msg = notif.userInfo?["message"] as? String ?? "Hey! Are we still meeting for coffee today? ☕️"
        IslandState.shared.triggerChatNotification(
            sender: sender,
            message: msg,
            app: .whatsapp,
            avatar: ChatApp.whatsapp.appIcon,
            isCustomAvatar: false,
            customBundleIdentifier: "net.whatsapp.WhatsApp"
        )
    }
    
    @objc private func quitAppAction() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
