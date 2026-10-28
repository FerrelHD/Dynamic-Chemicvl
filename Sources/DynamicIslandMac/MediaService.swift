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
    
    // MARK: - Fallback HD Album / Video Artwork Fetcher (iTunes Public CDN)
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
        
        var candidates: [String] = []
        // 1. If album name is provided and clean, prioritize title + album / artist
        if !album.isEmpty && album != "System Audio" {
            if !cleanArt.isEmpty && cleanArt != "System Audio" {
                candidates.append("\(clean) \(cleanArt) \(album)")
            }
            candidates.append("\(clean) \(album)")
        }
        
        // 2. Specific artist + title query (sanitized without minus-topic)
        let hasArtistInTitle = clean.lowercased().contains(cleanArt.lowercased())
        if !hasArtistInTitle && !cleanArt.isEmpty && cleanArt != "System Audio" {
            candidates.append("\(clean) \(cleanArt)")
        }
        
        // 3. Inverted "Artist - Song" / "Song - Artist" if title contains delimiter
        if clean.contains(" - ") {
            let parts = clean.components(separatedBy: " - ")
            if parts.count >= 2 {
                let p0 = parts[0].trimmingCharacters(in: .whitespaces)
                let p1 = parts[1].trimmingCharacters(in: .whitespaces)
                candidates.append("\(p0) \(p1)")
                candidates.append("\(p1) \(p0)")
            }
        }
        
        // 4. Fallback to clean title alone
        candidates.append(clean)
        
        searchITunesArtwork(candidates: candidates, index: 0, cacheKey: cacheKey, completion: completion)
    }
    
    private func searchITunesArtwork(candidates: [String], index: Int, cacheKey: String, completion: @escaping (Data?) -> Void) {
        guard index < candidates.count else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        
        // Sanitize query to prevent negative keyword exclusions in iTunes API (replace " - " with a space)
        let rawQuery = candidates[index]
        let query = rawQuery.replacingOccurrences(of: " - ", with: " ")
            .replacingOccurrences(of: " – ", with: " ")
            .replacingOccurrences(of: " — ", with: " ")
            
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=1") else {
            searchITunesArtwork(candidates: candidates, index: index + 1, cacheKey: cacheKey, completion: completion)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 4.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let artUrlStr = first["artworkUrl100"] as? String else {
                self?.searchITunesArtwork(candidates: candidates, index: index + 1, cacheKey: cacheKey, completion: completion)
                return
            }
            
            let hdArtUrlStr = artUrlStr.replacingOccurrences(of: "100x100bb.jpg", with: "600x600bb.jpg")
            guard let hdUrl = URL(string: hdArtUrlStr) else {
                self?.searchITunesArtwork(candidates: candidates, index: index + 1, cacheKey: cacheKey, completion: completion)
                return
            }
            
            URLSession.shared.dataTask(with: hdUrl) { [weak self] imgData, _, _ in
                if let imgData = imgData, !imgData.isEmpty {
                    self?.onlineArtworkCache[cacheKey] = imgData
                    DispatchQueue.main.async { completion(imgData) }
                } else {
                    self?.searchITunesArtwork(candidates: candidates, index: index + 1, cacheKey: cacheKey, completion: completion)
                }
            }.resume()
        }.resume()
    }
}
