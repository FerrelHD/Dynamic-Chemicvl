import AppKit
import Foundation
import SQLite3

public class NotificationListenerService {
    public static let shared = NotificationListenerService()
    
    private var timerSource: DispatchSourceTimer?
    private var dbPath: String?
    private var lastSeenRecId: Int64 = 0
    private var isRunning = false
    private let queue = DispatchQueue(label: "com.ferrel.notchflow.notificationcenter", qos: .utility)
    
    private init() {}
    
    public func startMonitoring() {
        guard !isRunning else { return }
        isRunning = true
        
        queue.async { [weak self] in
            guard let self = self else { return }
            self.dbPath = self.locateNotificationCenterDatabase()
            guard let path = self.dbPath else {
                NSLog("[NotchFlow] Notification Center DB not found in /var/folders")
                return
            }
            
            // Baseline: catch up to latest rec_id so old historical notifications are not spammed
            self.lastSeenRecId = self.fetchLatestRecId(at: path)
            NSLog("[NotchFlow] Notification Center monitor initialized at rec_id: %lld (db: %@)", self.lastSeenRecId, path)
            
            let t = DispatchSource.makeTimerSource(queue: self.queue)
            t.schedule(deadline: .now() + 0.5, repeating: 0.5, leeway: .milliseconds(50))
            t.setEventHandler { [weak self] in
                self?.pollNewNotifications()
            }
            t.resume()
            self.timerSource = t
        }
    }
    
    public func stopMonitoring() {
        isRunning = false
        timerSource?.cancel()
        timerSource = nil
    }
    
    private func locateNotificationCenterDatabase() -> String? {
        let base = "/var/folders"
        let fm = FileManager.default
        guard let subdirs1 = try? fm.contentsOfDirectory(atPath: base) else { return nil }
        
        for dir1 in subdirs1 {
            let path1 = "\(base)/\(dir1)"
            guard let subdirs2 = try? fm.contentsOfDirectory(atPath: path1) else { continue }
            for dir2 in subdirs2 {
                let candidate = "\(path1)/\(dir2)/0/com.apple.notificationcenter/db2/db"
                if fm.fileExists(atPath: candidate) {
                    return candidate
                }
            }
        }
        return nil
    }
    
    private func fetchLatestRecId(at path: String) -> Int64 {
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            return 0
        }
        defer { sqlite3_close(db) }
        
        var stmt: OpaquePointer?
        var maxId: Int64 = 0
        if sqlite3_prepare_v2(db, "SELECT MAX(rec_id) FROM record;", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                maxId = sqlite3_column_int64(stmt, 0)
            }
            sqlite3_finalize(stmt)
        }
        return maxId
    }
    
    private func pollNewNotifications() {
        guard isRunning, let path = dbPath else { return }
        
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            return
        }
        defer { sqlite3_close(db) }
        
        var stmt: OpaquePointer?
        let sql = "SELECT r.rec_id, a.identifier, r.data FROM record r JOIN app a ON r.app_id = a.app_id WHERE r.rec_id > ? ORDER BY r.rec_id ASC LIMIT 10;"
        
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return
        }
        defer { sqlite3_finalize(stmt) }
        
        sqlite3_bind_int64(stmt, 1, self.lastSeenRecId)
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            let recId = sqlite3_column_int64(stmt, 0)
            let appId = String(cString: sqlite3_column_text(stmt, 1))
            let blobBytes = sqlite3_column_bytes(stmt, 2)
            
            self.lastSeenRecId = max(self.lastSeenRecId, recId)
            
            guard blobBytes > 0, let blob = sqlite3_column_blob(stmt, 2) else { continue }
            let data = Data(bytes: blob, count: Int(blobBytes))
            
            guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                  let req = plist["req"] as? [String: Any] else {
                continue
            }
            
            var title = req["titl"] as? String ?? ""
            let body = req["body"] as? String ?? (req["subt"] as? String ?? "")
            
            // Clean up Unicode bidirectional marks (WhatsApp often prepends LTR mark \u200e)
            title = title.trimmingCharacters(in: CharacterSet(charactersIn: "\u{200E}\u{200F}\u{202A}\u{202C} \t\n\r"))
            
            // Filter noise
            if title.isEmpty && body.isEmpty { continue }
            let lowerApp = appId.lowercased()
            if lowerApp.hasPrefix("_system_center_") || lowerApp.contains("controlcenter.notifications") {
                continue
            }
            
            let chatApp: ChatApp = {
                if lowerApp.contains("whatsapp") { return .whatsapp }
                if lowerApp.contains("telegram") { return .telegram }
                if lowerApp.contains("mobilesms") || lowerApp.contains("ichat") { return .imessage }
                if lowerApp.contains("discord") { return .discord }
                if lowerApp.contains("slack") { return .slack }
                if lowerApp.contains("mail") { return .mail }
                return .other
            }()
            
            var appIcon: NSImage?
            if chatApp == .other {
                if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appId) {
                    appIcon = NSWorkspace.shared.icon(forFile: appUrl.path)
                }
            }
            
            let displaySender = title.isEmpty ? (chatApp == .other ? appId : chatApp.rawValue) : title
            NSLog("[NotchFlow] 🔔 NOTIFICATION DETECTED: rec_id=%lld, app=%@, title=%@, body=%@", recId, appId, displaySender, body)
            
            DispatchQueue.main.async {
                IslandState.shared.triggerChatNotification(
                    sender: displaySender,
                    message: body,
                    app: chatApp,
                    avatar: appIcon,
                    customBundleIdentifier: appId
                )
            }
        }
    }
}
