import AppKit
import ApplicationServices

public class NotificationListenerService {
    public static let shared = NotificationListenerService()
    
    private var timer: Timer?
    private var lastKnownBadges: [String: String] = [:]
    private var isInitialized = false
    
    private init() {}
    
    public func startMonitoring() {
        guard timer == nil else { return }
        
        // Scan every 2.0 seconds with low-priority background timer (zero CPU idle)
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            DispatchQueue.global(qos: .utility).async {
                self?.checkDockBadges()
            }
        }
        
        // Initial scan to establish baseline
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.checkDockBadges()
            self?.isInitialized = true
        }
    }
    
    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkDockBadges() {
        guard let dockApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dock" }) else { return }
        let dockEl = AXUIElementCreateApplication(dockApp.processIdentifier)
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockEl, kAXChildrenAttribute as CFString, &children) == .success,
              let list = children as? [AXUIElement] else { return }
        
        var currentBadges: [String: String] = [:]
        
        for listEl in list {
            var subKids: CFTypeRef?
            guard AXUIElementCopyAttributeValue(listEl, kAXChildrenAttribute as CFString, &subKids) == .success,
                  let appIcons = subKids as? [AXUIElement] else { continue }
            
            for icon in appIcons {
                var title: CFTypeRef?
                AXUIElementCopyAttributeValue(icon, kAXTitleAttribute as CFString, &title)
                var statusLabel: CFTypeRef?
                AXUIElementCopyAttributeValue(icon, "AXStatusLabel" as CFString, &statusLabel)
                
                guard let appTitle = title as? String else { continue }
                let badge = (statusLabel as? String) ?? ""
                currentBadges[appTitle] = badge
                
                // If initialized and badge changed to a new non-empty value
                if self.isInitialized {
                    let oldBadge = self.lastKnownBadges[appTitle] ?? ""
                    if !badge.isEmpty && badge != oldBadge {
                        self.handleNewNotification(appTitle: appTitle, badge: badge)
                    }
                }
            }
        }
        
        self.lastKnownBadges = currentBadges
    }
    
    private func handleNewNotification(appTitle: String, badge: String) {
        let lower = appTitle.lowercased()
        let chatApp: ChatApp? = {
            if lower.contains("whatsapp") { return .whatsapp }
            if lower.contains("telegram") { return .telegram }
            if lower.contains("message") { return .imessage }
            if lower.contains("discord") { return .discord }
            if lower.contains("slack") { return .slack }
            return nil
        }()
        
        guard let app = chatApp else { return }
        
        DispatchQueue.main.async {
            IslandState.shared.triggerChatNotification(
                sender: appTitle,
                message: "New notification (\(badge) unread)",
                app: app
            )
        }
    }
}
