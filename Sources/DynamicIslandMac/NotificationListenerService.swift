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
    
    // Direct WhatsApp Monitoring (KeyNotch-grade event driven)
    private let whatsAppSharedURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Group Containers/group.net.whatsapp.WhatsApp.shared")
    private var whatsAppWalSource: DispatchSourceFileSystemObject?
    private var whatsAppWalDebounceWorkItem: DispatchWorkItem?
    private var lastSeenWhatsAppPK: Int64 = 0
    private var lastDeliveredText: String = ""
    private var lastDeliveredTime: Date = Date.distantPast
    
    private init() {}
    
    public func startMonitoring() {
        guard !isRunning else { return }
        isRunning = true
        
        queue.async { [weak self] in
            guard let self = self else { return }
            self.dbPath = self.locateNotificationCenterDatabase()
            
            // 1. Establish Notification Center baseline
            if let path = self.dbPath {
                self.lastSeenRecId = self.fetchLatestRecId(at: path)
                NSLog("[NotchFlow] Notification Center monitor initialized at rec_id: %lld (db: %@)", self.lastSeenRecId, path)
            }
            
            // 2. Establish WhatsApp direct baseline & setup WAL listener
            self.setupWhatsAppDirectListener()
            
            let t = DispatchSource.makeTimerSource(queue: self.queue)
            t.schedule(deadline: .now() + 2.5, repeating: 2.5, leeway: .milliseconds(200))
            t.setEventHandler { [weak self] in
                guard let self = self else { return }
                self.pollNewNotifications()
                if self.whatsAppWalSource == nil {
                    self.setupWhatsAppDirectListener()
                }
            }
            t.resume()
            self.timerSource = t
        }
    }
    
    public func stopMonitoring() {
        isRunning = false
        timerSource?.cancel()
        timerSource = nil
        whatsAppWalDebounceWorkItem?.cancel()
        whatsAppWalDebounceWorkItem = nil
        whatsAppWalSource?.cancel()
        whatsAppWalSource = nil
    }
    
    // MARK: - Health & Full Disk Access Inspection
    public func checkDatabaseAccessibility() -> Bool {
        guard let path = dbPath ?? locateNotificationCenterDatabase() else { return false }
        var db: OpaquePointer?
        if sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK {
            var stmt: OpaquePointer?
            let canRead = (sqlite3_prepare_v2(db, "SELECT rec_id FROM record LIMIT 1;", -1, &stmt, nil) == SQLITE_OK)
            if stmt != nil { sqlite3_finalize(stmt) }
            sqlite3_close(db)
            return canRead
        }
        return false
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
    
    // MARK: - KeyNotch-Grade Direct WhatsApp Event Listener & Avatar Resolver
    private func setupWhatsAppDirectListener() {
        let chatDBPath = whatsAppSharedURL.appendingPathComponent("ChatStorage.sqlite").path
        guard FileManager.default.fileExists(atPath: chatDBPath) else { return }
        
        var db: OpaquePointer?
        let uri = "file:\(chatDBPath)?mode=ro"
        if sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK {
            var stmt: OpaquePointer?
            let sql = "SELECT MAX(Z_PK) FROM ZWAMESSAGE WHERE ZISFROMME = 0 AND ZMESSAGETYPE NOT IN (59, 10);"
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    self.lastSeenWhatsAppPK = sqlite3_column_int64(stmt, 0)
                }
                sqlite3_finalize(stmt)
            }
            sqlite3_close(db)
            NSLog("[NotchFlow] 💬 WhatsApp direct listener initialized at PK: %lld", self.lastSeenWhatsAppPK)
        }
        
        // Listen to ChatStorage.sqlite-wal file changes
        let walPath = whatsAppSharedURL.appendingPathComponent("ChatStorage.sqlite-wal").path
        guard FileManager.default.fileExists(atPath: walPath) else { return }
        let walFD = open(walPath, O_EVTONLY)
        guard walFD >= 0 else { return }
        
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: walFD,
            eventMask: [.write, .extend],
            queue: queue
        )
        src.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.whatsAppWalDebounceWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.checkNewWhatsAppMessages()
            }
            self.whatsAppWalDebounceWorkItem = work
            self.queue.asyncAfter(deadline: .now() + 0.20, execute: work)
        }
        src.setCancelHandler {
            close(walFD)
        }
        src.resume()
        self.whatsAppWalSource = src
    }
    
    private static func isBase64Token(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 16 && !trimmed.contains(" ") else { return false }
        let validBase64 = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+/=")
        return trimmed.unicodeScalars.allSatisfy { validBase64.contains($0) }
    }
    
    private func checkNewWhatsAppMessages() {
        let chatDBPath = whatsAppSharedURL.appendingPathComponent("ChatStorage.sqlite").path
        guard FileManager.default.fileExists(atPath: chatDBPath) else { return }
        
        var db: OpaquePointer?
        let uri = "file:\(chatDBPath)?mode=ro"
        guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            return
        }
        defer { sqlite3_close(db) }
        
        let query = """
        SELECT m.Z_PK, 
               COALESCE(NULLIF(s.ZPARTNERNAME, ''), ''), 
               COALESCE(m.ZTEXT, ''), 
               COALESCE(s.ZCONTACTJID, ''),
               COALESCE(NULLIF(p.ZPUSHNAME, ''), NULLIF(p2.ZPUSHNAME, ''), NULLIF(gm.ZCONTACTNAME, ''), '')
        FROM ZWAMESSAGE m
        LEFT JOIN ZWACHATSESSION s ON m.ZCHATSESSION = s.Z_PK
        LEFT JOIN ZWAGROUPMEMBER gm ON m.ZGROUPMEMBER = gm.Z_PK
        LEFT JOIN ZWAPROFILEPUSHNAME p ON gm.ZMEMBERJID = p.ZJID
        LEFT JOIN ZWAPROFILEPUSHNAME p2 ON m.ZFROMJID = p2.ZJID
        WHERE m.ZISFROMME = 0 AND m.ZMESSAGETYPE NOT IN (59, 10) AND m.Z_PK > ?
        ORDER BY m.Z_PK ASC LIMIT 5;
        """
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        
        sqlite3_bind_int64(stmt, 1, lastSeenWhatsAppPK)
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            let pk = sqlite3_column_int64(stmt, 0)
            let partnerName = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
            var text = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
            let jid = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
            let memberName = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
            
            self.lastSeenWhatsAppPK = max(self.lastSeenWhatsAppPK, pk)
            
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { text = "New Message" }
            
            // Format dynamic sender name: display real contact / sender name, never generic "WhatsApp" or raw Base64 token
            let sender: String = {
                let cleanPartner = NotificationListenerService.isBase64Token(partnerName) ? "" : partnerName
                let cleanMember = NotificationListenerService.isBase64Token(memberName) ? "" : memberName
                
                let isGroup = jid.contains("@g.us")
                if isGroup {
                    if !cleanMember.isEmpty && !cleanPartner.isEmpty && cleanMember != cleanPartner {
                        return "\(cleanMember) (\(cleanPartner))"
                    }
                    if !cleanPartner.isEmpty { return cleanPartner }
                    if !cleanMember.isEmpty { return cleanMember }
                    return "Group Message"
                }
                if !cleanPartner.isEmpty && cleanPartner.lowercased() != "whatsapp" {
                    return cleanPartner
                }
                if !cleanMember.isEmpty && cleanMember.lowercased() != "whatsapp" {
                    return cleanMember
                }
                return "WhatsApp"
            }()
            
            let customAvatar = resolveWhatsAppAvatar(for: jid)
            let finalAvatar = customAvatar ?? ChatApp.whatsapp.appIcon
            let hasCustom = (customAvatar != nil)
            
            self.lastDeliveredText = text
            self.lastDeliveredTime = Date()
            
            NSLog("[NotchFlow] 💬 WHATSAPP DIRECT DETECTED: pk=%lld, sender=%@, text=%@", pk, sender, text)
            DispatchQueue.main.async {
                IslandState.shared.triggerChatNotification(
                    sender: sender,
                    message: text,
                    app: .whatsapp,
                    avatar: finalAvatar,
                    isCustomAvatar: hasCustom,
                    customBundleIdentifier: "net.whatsapp.WhatsApp"
                )
            }
        }
    }
    
    private func resolveWhatsAppAvatar(for jid: String) -> NSImage? {
        let trimmed = jid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let cleanJID = trimmed.components(separatedBy: "@").first ?? trimmed
        
        let dbPath = whatsAppSharedURL.appendingPathComponent("ChatStorage.sqlite").path
        guard FileManager.default.fileExists(atPath: dbPath) else { return nil }
        
        var db: OpaquePointer?
        let uri = "file:\(dbPath)?mode=ro"
        guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }
        
        let query = "SELECT ZPATH FROM ZWAPROFILEPICTUREITEM WHERE ZJID LIKE '%' || ? || '%' AND ZPATH IS NOT NULL ORDER BY Z_PK DESC LIMIT 1;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (cleanJID as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let text = sqlite3_column_text(stmt, 0) {
                    let relPath = String(cString: text)
                    sqlite3_finalize(stmt)
                    
                    let fullJpg = whatsAppSharedURL.appendingPathComponent("\(relPath).jpg").path
                    if FileManager.default.fileExists(atPath: fullJpg), let img = NSImage(contentsOfFile: fullJpg) {
                        return img
                    }
                    let fullThumb = whatsAppSharedURL.appendingPathComponent("\(relPath).thumb").path
                    if FileManager.default.fileExists(atPath: fullThumb), let img = NSImage(contentsOfFile: fullThumb) {
                        return img
                    }
                    return nil
                }
            }
            sqlite3_finalize(stmt)
        }
        return nil
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
            
            var rawTitle = req["titl"] as? String ?? ""
            var subtitle = req["subt"] as? String ?? ""
            var body = req["body"] as? String ?? ""
            
            // Clean up Unicode bidirectional marks (WhatsApp often prepends LTR mark \u200e)
            let bidiSet = CharacterSet(charactersIn: "\u{200E}\u{200F}\u{202A}\u{202C} \t\n\r")
            rawTitle = rawTitle.trimmingCharacters(in: bidiSet)
            subtitle = subtitle.trimmingCharacters(in: bidiSet)
            body = body.trimmingCharacters(in: bidiSet)
            
            // Filter noise
            if rawTitle.isEmpty && body.isEmpty && subtitle.isEmpty { continue }
            let lowerApp = appId.lowercased()
            if lowerApp.hasPrefix("_system_center_") || lowerApp.contains("controlcenter.notifications") {
                continue
            }
            
            let chatApp: ChatApp = {
                if lowerApp.contains("whatsapp") || rawTitle.lowercased().contains("whatsapp") { return .whatsapp }
                if lowerApp.contains("telegram") { return .telegram }
                if lowerApp.contains("mobilesms") || lowerApp.contains("ichat") { return .imessage }
                if lowerApp.contains("discord") { return .discord }
                if lowerApp.contains("slack") { return .slack }
                if lowerApp.contains("mail") { return .mail }
                return .other
            }()
            
            // Deduplicate if already triggered via WhatsApp direct WAL listener
            if lowerApp.contains("whatsapp") && body == self.lastDeliveredText && Date().timeIntervalSince(self.lastDeliveredTime) < 3.0 {
                continue
            }
            
            // Resolve actual sender name dynamically:
            // Never display generic app name "WhatsApp" as the sender title when contact/subtitle is available!
            var displaySender = rawTitle
            if displaySender.lowercased() == "whatsapp" {
                if !subtitle.isEmpty && subtitle.lowercased() != "whatsapp" {
                    displaySender = subtitle
                } else if let colonIdx = body.firstIndex(of: ":") {
                    let prefix = String(body[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                    let remaining = String(body[body.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                    if !prefix.isEmpty && prefix.count < 30 && !remaining.isEmpty {
                        displaySender = prefix
                        body = remaining
                    }
                } else if !subtitle.isEmpty {
                    displaySender = subtitle
                } else {
                    displaySender = "WhatsApp"
                }
            } else if displaySender.isEmpty {
                displaySender = !subtitle.isEmpty ? subtitle : (chatApp == .other ? appId : chatApp.rawValue)
            }
            if NotificationListenerService.isBase64Token(displaySender) {
                displaySender = (!subtitle.isEmpty && !NotificationListenerService.isBase64Token(subtitle)) ? subtitle : (chatApp == .other ? appId : chatApp.rawValue)
            }
            
            if body.isEmpty && !subtitle.isEmpty && displaySender != subtitle {
                body = subtitle
            }
            
            var appIcon: NSImage?
            if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appId) {
                appIcon = NSWorkspace.shared.icon(forFile: appUrl.path)
            } else {
                appIcon = chatApp.appIcon
            }
            appIcon?.size = NSSize(width: 76, height: 76)
            
            NSLog("[NotchFlow] 🔔 NOTIFICATION DETECTED: rec_id=%lld, app=%@, title=%@, body=%@", recId, appId, displaySender, body)
            
            let isCall = (chatApp == .whatsapp || lowerApp.contains("whatsapp")) && (
                body.lowercased().contains("call") ||
                body.lowercased().contains("panggilan") ||
                subtitle.lowercased().contains("call") ||
                subtitle.lowercased().contains("panggilan") ||
                rawTitle.lowercased().contains("call") ||
                rawTitle.lowercased().contains("panggilan")
            )
            
            DispatchQueue.main.async {
                if isCall {
                    IslandState.shared.triggerCallNotification(
                        callerName: displaySender,
                        subtitle: "WhatsApp Audio...",
                        avatar: appIcon
                    )
                } else {
                    IslandState.shared.triggerChatNotification(
                        sender: displaySender,
                        message: body,
                        app: chatApp,
                        avatar: appIcon,
                        isCustomAvatar: false,
                        customBundleIdentifier: appId
                    )
                }
            }
        }
    }
}
