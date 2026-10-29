import Foundation
import AppKit

public class MediaService {
    public static let shared = MediaService()
    
    // Tipe fungsi C dari MediaRemote.framework
    private typealias MRGetNowPlayingInfoFn = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias MRSendCommandFn = @convention(c) (Int, AnyObject?) -> Bool
    private typealias MRSetElapsedTimeFn = @convention(c) (Double) -> Void
    
    private var getNowPlayingInfoPtr: MRGetNowPlayingInfoFn?
    private var sendCommandPtr: MRSendCommandFn?
    private var setElapsedTimePtr: MRSetElapsedTimeFn?
    
    private var isPolling = false
    private let queryQueue = DispatchQueue(label: "com.dynamicisland.mediaquery", qos: .utility)
    private var onlineArtworkCache: [String: Data] = [:]
    
    // Command codes
    public let cmdPlay: Int = 0
    public let cmdPause: Int = 1
    public let cmdTogglePlayPause: Int = 2
    public let cmdNextTrack: Int = 4
    public let cmdPreviousTrack: Int = 5
    
    public init() {
        // Load dynamically dari MediaRemote.framework bawaan macOS
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework"
        if let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: path)) {
            if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) {
                self.getNowPlayingInfoPtr = unsafeBitCast(ptr, to: MRGetNowPlayingInfoFn.self)
            }
            if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) {
                self.sendCommandPtr = unsafeBitCast(ptr, to: MRSendCommandFn.self)
            }
            if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSetElapsedTime" as CFString) {
                self.setElapsedTimePtr = unsafeBitCast(ptr, to: MRSetElapsedTimeFn.self)
            }
        }
    }
    
    public struct UniversalMediaInfo {
        public let isPlaying: Bool
        public let title: String
        public let artist: String
        public let album: String
        public let position: Double
        public let duration: Double
        public let artworkData: Data?
        public let isTransientSocial: Bool
    }
    
    // MARK: - Metadata Sanitizers
    public static func cleanArtistName(_ raw: String) -> String {
        var cleaned = raw
        let garbageSuffixes = [" - Topic", "- Topic", "-Topic", " – Topic", " — Topic"]
        for suffix in garbageSuffixes {
            if cleaned.hasSuffix(suffix) {
                cleaned = String(cleaned.dropLast(suffix.count))
            }
        }
        let patterns = [
            " (Official Audio)", " (Official Video)", " (Official Music Video)", " (Lyric Video)", " (Audio)",
            " [Official Audio]", " [Official Video]", " [Official Music Video]", " [Lyric Video]", " [Audio]"
        ]
        for p in patterns {
            cleaned = cleaned.replacingOccurrences(of: p, with: "", options: .caseInsensitive)
        }
        cleaned = cleaned.replacingOccurrences(of: " - Topic", with: "", options: .caseInsensitive)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public static func isTransientSocialMedia(title: String, artist: String, duration: Double) -> Bool {
        let lowerTitle = title.lowercased()
        let lowerArtist = artist.lowercased()
        
        // Explicit social feed keywords
        let socialKeywords = ["instagram", "tiktok", "reels", "shorts", "twitter.com", "x.com", "threads.net", "facebook"]
        for keyword in socialKeywords {
            if lowerTitle.contains(keyword) || lowerArtist.contains(keyword) {
                return true
            }
        }
        
        // Short video clip (< 45s) without a named musical artist
        if duration > 0 && duration <= 45.0 && (artist.isEmpty || artist == "System Audio" || artist == "Safari" || artist == "Google Chrome") {
            return true
        }
        
        return false
    }
    
    public func startMonitoring(onChange: @escaping (UniversalMediaInfo) -> Void) {
        guard !isPolling else { return }
        isPolling = true
        
        queryQueue.async { [weak self] in
            while self?.isPolling == true {
                self?.fetchMediaInfo(completion: onChange)
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
    }
    
    public func stopMonitoring() {
        isPolling = false
    }
    
    public func fetchMediaInfo(completion: @escaping (UniversalMediaInfo) -> Void) {
        if let getInfo = self.getNowPlayingInfoPtr {
            getInfo(DispatchQueue.main) { dict in
                let title = dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
                let rawArtist = dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
                let album = dict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
                let rate = dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0.0
                let isPlaying = rate > 0.0
                let duration = dict["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0.0
                var elapsed = dict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0.0
                
                // Realtime playback position interpolation using system timestamp
                if isPlaying, let timestamp = dict["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date {
                    let delta = Date().timeIntervalSince(timestamp)
                    if delta > 0 && delta < duration {
                        elapsed = min(duration, elapsed + (delta * rate))
                    }
                }
                
                let artworkData = dict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
                let cleanArtist = MediaService.cleanArtistName(rawArtist)
                let resolvedArtist = cleanArtist.isEmpty ? (album.isEmpty ? "System Audio" : album) : cleanArtist
                let isTransient = MediaService.isTransientSocialMedia(title: title, artist: resolvedArtist, duration: duration)
                
                if !title.isEmpty {
                    let info = UniversalMediaInfo(
                        isPlaying: isPlaying,
                        title: title,
                        artist: resolvedArtist,
                        album: album,
                        position: elapsed,
                        duration: duration,
                        artworkData: artworkData,
                        isTransientSocial: isTransient
                    )
                    completion(info)
                    return
                } else {
                    // Fallback when no media is active
                    let fallback = UniversalMediaInfo(
                        isPlaying: false,
                        title: "No Media Playing",
                        artist: "Play music or video from any app",
                        album: "",
                        position: 0,
                        duration: 0,
                        artworkData: nil,
                        isTransientSocial: false
                    )
                    completion(fallback)
                }
            }
        }
    }
    
    // MARK: - Global Media Remote Commands
    public func togglePlayPause() {
        if let send = sendCommandPtr {
            _ = send(cmdTogglePlayPause, nil)
        }
    }
    
    public func nextTrack() {
        if let send = sendCommandPtr {
            _ = send(cmdNextTrack, nil)
        }
    }
    
    public func previousTrack() {
        if let send = sendCommandPtr {
            _ = send(cmdPreviousTrack, nil)
        }
    }
    
    public func seek(to seconds: Double) {
        if let setElapsed = self.setElapsedTimePtr {
            setElapsed(seconds)
        }
    }
    
    // MARK: - Fallback HD Album / Video Artwork Fetcher (YouTube HD CDN & Verified iTunes)
    public func fetchOnlineArtwork(title: String, artist: String, album: String = "", completion: @escaping (Data?) -> Void) {
        let clean = LyricsService.cleanTrackTitle(title)
        let cleanArt = MediaService.cleanArtistName(artist)
        guard !clean.isEmpty && clean != "No Media Playing" else {
            completion(nil)
            return
        }
        let cacheKey = "\(clean.lowercased())_\(cleanArt.lowercased())_\(album.lowercased())"
        if let cached = onlineArtworkCache[cacheKey] {
            completion(cached)
            return
        }
        
        // 1. YouTube & YouTube Music Priority: If Chrome or Safari has an active watch URL, fetch 100% exact thumbnail
        if let ytVideoId = MediaService.extractActiveYouTubeVideoId() {
            let ytCacheKey = "yt_\(ytVideoId)"
            if let cachedYt = onlineArtworkCache[ytCacheKey] {
                completion(cachedYt)
                return
            }
            fetchYouTubeThumbnail(videoId: ytVideoId) { [weak self] ytData in
                if let ytData = ytData, !ytData.isEmpty {
                    self?.onlineArtworkCache[ytCacheKey] = ytData
                    self?.onlineArtworkCache[cacheKey] = ytData
                    completion(ytData)
                    return
                } else {
                    // Fallback to verified search if YouTube thumbnail fails
                    self?.beginVerifiedSearch(clean: clean, cleanArt: cleanArt, album: album, cacheKey: cacheKey, completion: completion)
                }
            }
            return
        }
        
        beginVerifiedSearch(clean: clean, cleanArt: cleanArt, album: album, cacheKey: cacheKey, completion: completion)
    }
    
    private func beginVerifiedSearch(clean: String, cleanArt: String, album: String, cacheKey: String, completion: @escaping (Data?) -> Void) {
        var candidates: [String] = []
        if !album.isEmpty && album != "System Audio" {
            if !cleanArt.isEmpty && cleanArt != "System Audio" {
                candidates.append("\(clean) \(cleanArt) \(album)")
            }
            candidates.append("\(clean) \(album)")
        }
        
        let hasArtistInTitle = clean.lowercased().contains(cleanArt.lowercased())
        if !hasArtistInTitle && !cleanArt.isEmpty && cleanArt != "System Audio" {
            candidates.append("\(clean) \(cleanArt)")
        }
        
        if clean.contains(" - ") {
            let parts = clean.components(separatedBy: " - ")
            if parts.count >= 2 {
                let p0 = parts[0].trimmingCharacters(in: .whitespaces)
                let p1 = parts[1].trimmingCharacters(in: .whitespaces)
                candidates.append("\(p0) \(p1)")
                candidates.append("\(p1) \(p0)")
            }
        }
        candidates.append(clean)
        
        searchVerifiedArtwork(candidates: candidates, index: 0, cleanTitle: clean, cleanArt: cleanArt, cacheKey: cacheKey, completion: completion)
    }
    
    // MARK: - Native YouTube / YouTube Music Video ID Extractor (Zero-Permission AppleScript)
    public static func extractActiveYouTubeVideoId() -> String? {
        let script = """
        tell application "Google Chrome"
            if not (exists windows) then return ""
            repeat with w in windows
                repeat with t in tabs of w
                    set u to URL of t
                    if u contains "music.youtube.com/watch" or u contains "youtube.com/watch" then
                        return u
                    end if
                end repeat
            end repeat
            return ""
        end tell
        """
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let output = appleScript.executeAndReturnError(&error)
            let urlString = output.stringValue ?? ""
            if !urlString.isEmpty,
               let url = URL(string: urlString),
               let comp = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                if let v = comp.queryItems?.first(where: { $0.name == "v" })?.value, !v.isEmpty {
                    return v
                }
            }
        }
        return nil
    }
    
    private func fetchYouTubeThumbnail(videoId: String, completion: @escaping (Data?) -> Void) {
        // First try HD maxresdefault, fallback to hqdefault
        let maxresUrl = URL(string: "https://img.youtube.com/vi/\(videoId)/maxresdefault.jpg")!
        let hqUrl = URL(string: "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg")!
        
        var req = URLRequest(url: maxresUrl)
        req.timeoutInterval = 3.0
        
        URLSession.shared.dataTask(with: req) { data, resp, _ in
            if let http = resp as? HTTPURLResponse, http.statusCode == 200, let data = data, !data.isEmpty {
                DispatchQueue.main.async { completion(data) }
            } else {
                var hqReq = URLRequest(url: hqUrl)
                hqReq.timeoutInterval = 3.0
                URLSession.shared.dataTask(with: hqReq) { hqData, hqResp, _ in
                    if let http = hqResp as? HTTPURLResponse, http.statusCode == 200, let hqData = hqData, !hqData.isEmpty {
                        DispatchQueue.main.async { completion(hqData) }
                    } else {
                        DispatchQueue.main.async { completion(nil) }
                    }
                }.resume()
            }
        }.resume()
    }
    
    // MARK: - Verified Strict iTunes Matcher (Rejects Mismatched Songs)
    private func searchVerifiedArtwork(
        candidates: [String],
        index: Int,
        cleanTitle: String,
        cleanArt: String,
        cacheKey: String,
        completion: @escaping (Data?) -> Void
    ) {
        guard index < candidates.count else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        
        let rawQuery = candidates[index]
        let query = rawQuery.replacingOccurrences(of: " - ", with: " ")
            .replacingOccurrences(of: " – ", with: " ")
            .replacingOccurrences(of: " — ", with: " ")
            
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=5") else {
            searchVerifiedArtwork(candidates: candidates, index: index + 1, cleanTitle: cleanTitle, cleanArt: cleanArt, cacheKey: cacheKey, completion: completion)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 4.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self = self,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                self?.searchVerifiedArtwork(candidates: candidates, index: index + 1, cleanTitle: cleanTitle, cleanArt: cleanArt, cacheKey: cacheKey, completion: completion)
                return
            }
            
            let qT = cleanTitle.lowercased()
            let qA = cleanArt.lowercased()
            
            // Find verified match that actually corresponds to this song/artist
            var matchedItem: [String: Any]?
            for item in results {
                let trackName = (item["trackName"] as? String ?? "").lowercased()
                let artistName = (item["artistName"] as? String ?? "").lowercased()
                
                let titleMatch = trackName.contains(qT) || qT.contains(trackName) || cleanTitle.count < 3
                let artistMatch = qA.isEmpty || qA == "system audio" || artistName.contains(qA) || qA.contains(artistName)
                
                if titleMatch && artistMatch {
                    matchedItem = item
                    break
                }
            }
            
            // If candidates didn't match closely, try next candidate or return nil (prevent wrong random cover)
            guard let item = matchedItem, let artUrlStr = item["artworkUrl100"] as? String else {
                self.searchVerifiedArtwork(candidates: candidates, index: index + 1, cleanTitle: cleanTitle, cleanArt: cleanArt, cacheKey: cacheKey, completion: completion)
                return
            }
            
            let hdArtUrlStr = artUrlStr.replacingOccurrences(of: "100x100bb.jpg", with: "600x600bb.jpg")
            guard let hdUrl = URL(string: hdArtUrlStr) else {
                self.searchVerifiedArtwork(candidates: candidates, index: index + 1, cleanTitle: cleanTitle, cleanArt: cleanArt, cacheKey: cacheKey, completion: completion)
                return
            }
            
            URLSession.shared.dataTask(with: hdUrl) { [weak self] imgData, _, _ in
                if let imgData = imgData, !imgData.isEmpty {
                    self?.onlineArtworkCache[cacheKey] = imgData
                    DispatchQueue.main.async { completion(imgData) }
                } else {
                    self?.searchVerifiedArtwork(candidates: candidates, index: index + 1, cleanTitle: cleanTitle, cleanArt: cleanArt, cacheKey: cacheKey, completion: completion)
                }
            }.resume()
        }.resume()
    }
}
