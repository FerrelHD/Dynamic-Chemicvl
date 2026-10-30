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
    private let artCacheLock = NSLock()
    private func artCached(_ key: String) -> Data? {
        self.artCacheLock.lock()
        defer { self.artCacheLock.unlock() }
        return self.onlineArtworkCache[key]
    }
    private func artStore(_ key: String, _ data: Data) {
        self.artCacheLock.lock()
        self.onlineArtworkCache[key] = data
        self.artCacheLock.unlock()
    }
    private static let appleScriptQueue = DispatchQueue(label: "com.dynamicisland.applescript", qos: .utility)
    
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
    
    // MARK: - Metadata Sanitizers & KeyNotch YouTube Engine
    public static func cleanVideoTitle(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Remove notification badges at the beginning, e.g. "(1) ", "(2) "
        if let badgeRegex = try? NSRegularExpression(pattern: "^\\([0-9]+\\)\\s*") {
            let range = NSRange(s.startIndex..., in: s)
            s = badgeRegex.stringByReplacingMatches(in: s, options: [], range: range, withTemplate: "")
        }
        
        // 2. Remove trailing YouTube suffixes
        let trailingSuffixes = [
            " - YouTube", " – YouTube", " — YouTube", " | YouTube",
            " - topic", " – topic", " — topic",
            " - Topic", " – Topic", " — Topic"
        ]
        for suf in trailingSuffixes {
            if s.lowercased().hasSuffix(suf.lowercased()) {
                s = String(s.dropLast(suf.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // 3. Remove 35+ common noise tags
        let noiseTags = [
            "(Official Video)", "(Official Music Video)", "[Official Video]",
            "[Official Music Video]", "(Official Audio)", "[Official Audio]",
            "(Official Visualizer)", "[Official Visualizer]",
            "(Lyric Video)", "[Lyric Video]", "(Lyrics Video)", "[Lyrics Video]",
            "(Audio)", "(Video)", "(Visualizer)", "[Visualizer]", "(Live)", "[Live]",
            "(Lyrics)", "[Lyrics]", "(Lyric)", "[Lyric]",
            ", lyric video", ", lyrics video", ", official video", ", visualizer",
            "| lyric video", "| lyrics video", "| official video",
            "(Tiktok Version)", "[Tiktok Version]", "(Speed Up)", "[Speed Up]",
            "(Slowed + Reverb)", "[Slowed + Reverb]", "(Slowed and Reverb)", "[Slowed and Reverb]",
            "(Remix)", "[Remix]", "(HD)", "[HD]", "(4K)", "[4K]", "(4K 60FPS)", "[4K 60FPS]",
            "| VEVO", "(VEVO)", "[VEVO]"
        ]
        for tag in noiseTags {
            if let r = s.range(of: tag, options: .caseInsensitive) {
                s.removeSubrange(r)
            }
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

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

    public static func splitArtistAndTitle(rawTitle: String, rawArtist: String) -> (artist: String, title: String) {
        let preCleanedTitle = cleanVideoTitle(rawTitle)
        var artist = cleanArtistName(rawArtist)
        var title = preCleanedTitle
        
        let lowerArtist = artist.lowercased()
        let isGenericArtist = artist.isEmpty || lowerArtist == "system audio" || lowerArtist == "youtube" || lowerArtist == "google chrome" || lowerArtist == "safari" || lowerArtist == "arc" || lowerArtist == "brave"
        
        // Format 1: "Artist - Song Title"
        var found = false
        for sep in [" - ", " – ", " — "] {
            if preCleanedTitle.contains(sep) {
                let parts = preCleanedTitle.components(separatedBy: sep)
                if parts.count >= 2 {
                    let aPart = cleanArtistName(cleanVideoTitle(parts[0]))
                    let tPart = cleanVideoTitle(parts[1...].joined(separator: sep))
                    if !aPart.isEmpty && !tPart.isEmpty {
                        title = tPart
                        if isGenericArtist {
                            artist = aPart
                        }
                        found = true
                        break
                    }
                }
            }
        }
        
        // Format 2: "Song Title by Artist"
        if !found && title.contains(" by ") {
            let parts = title.components(separatedBy: " by ")
            if parts.count >= 2 {
                let tPart = cleanVideoTitle(parts[0])
                let aPart = cleanArtistName(cleanVideoTitle(parts[1...].joined(separator: " by ")))
                if !tPart.isEmpty && !aPart.isEmpty {
                    title = tPart
                    if isGenericArtist {
                        artist = aPart
                    }
                }
            }
        }
        
        let finalArtist = artist.isEmpty ? "System Audio" : artist
        let finalTitle = title.isEmpty ? rawTitle : title
        return (artist: finalArtist, title: finalTitle)
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
                let rawTitle = dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
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
                let (resolvedArtist, resolvedTitle) = MediaService.splitArtistAndTitle(rawTitle: rawTitle, rawArtist: rawArtist)
                let isTransient = MediaService.isTransientSocialMedia(title: resolvedTitle, artist: resolvedArtist, duration: duration)
                
                if !resolvedTitle.isEmpty && resolvedTitle != "No Media Playing" {
                    let info = UniversalMediaInfo(
                        isPlaying: isPlaying,
                        title: resolvedTitle,
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
    public func fetchOnlineArtwork(
        title: String,
        artist: String,
        album: String = "",
        duration: Double = 0,
        completion: @escaping (Data?) -> Void
    ) {
        let (cleanArt, clean) = MediaService.splitArtistAndTitle(rawTitle: title, rawArtist: artist)
        guard !clean.isEmpty && clean != "No Media Playing" else { completion(nil); return }
        let cacheKey = "\(clean.lowercased())_\(cleanArt.lowercased())_\(album.lowercased())"
        if let cached = self.artCached(cacheKey) { completion(cached); return }

        MediaService.appleScriptQueue.async { [weak self] in
            let videoId = MediaService.extractActiveYouTubeVideoId(matching: clean)
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let id = videoId {
                    let ytKey = "yt_\(id)"
                    if let c = self.artCached(ytKey) { completion(c); return }
                    self.fetchYouTubeThumbnail(videoId: id) { [weak self] data in
                        guard let self = self else { return }
                        if let data = data, !data.isEmpty {
                            self.artStore(ytKey, data)
                            self.artStore(cacheKey, data)
                            completion(data)
                        } else {
                            self.beginVerifiedSearch(clean: clean, cleanArt: cleanArt, album: album,
                                                     duration: duration, cacheKey: cacheKey, completion: completion)
                        }
                    }
                } else {
                    self.beginVerifiedSearch(clean: clean, cleanArt: cleanArt, album: album,
                                             duration: duration, cacheKey: cacheKey, completion: completion)
                }
            }
        }
    }
    
    private func beginVerifiedSearch(
        clean: String,
        cleanArt: String,
        album: String,
        duration: Double,
        cacheKey: String,
        completion: @escaping (Data?) -> Void
    ) {
        var candidates: [String] = []
        let hasValidArtist = !cleanArt.isEmpty && cleanArt != "System Audio" && cleanArt.lowercased() != "youtube" && cleanArt.lowercased() != "google chrome"
        
        if hasValidArtist {
            candidates.append("\(cleanArt) \(clean)")
            candidates.append("\(clean) \(cleanArt)")
        }
        
        // Clean out any feat./ft. tags for a focused search query candidate
        let strippedFeat = clean.replacingOccurrences(of: "(?i)\\s*(?:ft|feat|featuring)\\.?\\s+.*", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        if strippedFeat != clean && !strippedFeat.isEmpty {
            if hasValidArtist {
                candidates.append("\(cleanArt) \(strippedFeat)")
            }
            candidates.append(strippedFeat)
        }
        
        if !album.isEmpty && album != "System Audio" {
            if hasValidArtist {
                candidates.append("\(cleanArt) \(clean) \(album)")
            }
            candidates.append("\(clean) \(album)")
        }
        
        candidates.append(clean)
        
        searchVerifiedArtwork(candidates: candidates, index: 0, cleanTitle: clean, cleanArt: cleanArt, album: album, duration: duration, cacheKey: cacheKey, completion: completion)
    }
    
    // MARK: - Native YouTube / YouTube Music Video ID Extractor (Zero-Permission AppleScript)
    public static func extractActiveYouTubeVideoId(matching trackTitle: String) -> String? {
        // Jangan jalankan script kalau Chrome tidak aktif: itu akan meluncurkannya.
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.Chrome").isEmpty
        else { return nil }

        let script = """
        tell application "Google Chrome"
            set out to ""
            repeat with w in windows
                set urls to URL of tabs of w
                set titles to title of tabs of w
                repeat with i from 1 to count of urls
                    set u to item i of urls
                    if u contains "youtube.com/watch" then
                        set out to out & u & tab & (item i of titles) & linefeed
                    end if
                end repeat
            end repeat
            return out
        end tell
        """
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return nil }
        let output = appleScript.executeAndReturnError(&error).stringValue ?? ""
        if error != nil || output.isEmpty { return nil }   // mis. izin Automation ditolak

        let want = TitleMatching.core(trackTitle)
        guard !want.isEmpty else { return nil }
        for line in output.components(separatedBy: "\n") {
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 2,
                  let url = URL(string: parts[0]),
                  let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let v = comps.queryItems?.first(where: { $0.name == "v" })?.value, !v.isEmpty
            else { continue }
            if TitleMatching.normalize(parts[1]).contains(want) { return v }
        }
        return nil
    }
    
    public func fetchYouTubeThumbnail(videoId: String, completion: @escaping (Data?) -> Void) {
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
        album: String,
        duration: Double,
        cacheKey: String,
        completion: @escaping (Data?) -> Void
    ) {
        guard index < candidates.count else {
            // iTunes search exhausted with 0 matches (non-official upload/cover/remix).
            // Fallback to validated YouTube thumbnail search using cleanTitle and cleanArt.
            searchYouTubeThumbnailFallback(cleanTitle: cleanTitle, cleanArt: cleanArt, cacheKey: cacheKey, completion: completion)
            return
        }
        
        let rawQuery = candidates[index]
        let query = rawQuery.replacingOccurrences(of: " - ", with: " ")
            .replacingOccurrences(of: " – ", with: " ")
            .replacingOccurrences(of: " — ", with: " ")
            
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=5") else {
            self.searchVerifiedArtwork(candidates: candidates, index: index + 1, cleanTitle: cleanTitle, cleanArt: cleanArt, album: album, duration: duration, cacheKey: cacheKey, completion: completion)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 4.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self = self,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                self?.searchVerifiedArtwork(candidates: candidates, index: index + 1, cleanTitle: cleanTitle, cleanArt: cleanArt, album: album, duration: duration, cacheKey: cacheKey, completion: completion)
                return
            }
            
            let wantTitle = TitleMatching.core(cleanTitle)
            let wantArtist = TitleMatching.normalize(cleanArt)
            let isGenericArtist = wantArtist.isEmpty || ["system audio", "youtube", "google chrome", "safari"].contains(wantArtist)

            var matchedItem: [String: Any]?
            if !wantTitle.isEmpty {
                for item in results {
                    // Judul harus SAMA, bukan sekadar mengandung ("sky" mengandung banyak lagu lain).
                    guard TitleMatching.core(item["trackName"] as? String ?? "") == wantTitle else { continue }
                    if !isGenericArtist {
                        guard TitleMatching.artistsMatch(item["artistName"] as? String ?? "", cleanArt) else { continue }
                    }
                    // Durasi: lebih longgar kalau artis diketahui, ketat kalau tidak.
                    let ms = (item["trackTimeMillis"] as? Double) ?? 0
                    let tolerance: Double = isGenericArtist ? 4 : 10
                    if duration > 0, ms > 0, abs(ms / 1000 - duration) > tolerance { continue }
                    // Tanpa artis dan tanpa durasi: tidak cukup bukti.
                    if isGenericArtist && duration <= 0 { continue }
                    matchedItem = item
                    break
                }
            }
            
            // TIDAK ADA fallback "artis ATAU judul cocok, ambil hasil pertama". Cover kosong lebih baik daripada cover lagu lain.
            guard let item = matchedItem, let artUrlStr = item["artworkUrl100"] as? String else {
                self.searchVerifiedArtwork(candidates: candidates, index: index + 1, cleanTitle: cleanTitle, cleanArt: cleanArt, album: album, duration: duration, cacheKey: cacheKey, completion: completion)
                return
            }
            
            let hdArtUrlStr = artUrlStr.replacingOccurrences(of: "100x100bb.jpg", with: "600x600bb.jpg")
            guard let hdUrl = URL(string: hdArtUrlStr) else {
                self.searchVerifiedArtwork(candidates: candidates, index: index + 1, cleanTitle: cleanTitle, cleanArt: cleanArt, album: album, duration: duration, cacheKey: cacheKey, completion: completion)
                return
            }
            
            URLSession.shared.dataTask(with: hdUrl) { [weak self] imgData, _, _ in
                guard let self = self else { return }
                if let imgData = imgData, !imgData.isEmpty {
                    self.artStore(cacheKey, imgData)
                    DispatchQueue.main.async { completion(imgData) }
                } else {
                    self.searchVerifiedArtwork(candidates: candidates, index: index + 1, cleanTitle: cleanTitle, cleanArt: cleanArt, album: album, duration: duration, cacheKey: cacheKey, completion: completion)
                }
            }.resume()
        }.resume()
    }
    
    // MARK: - Ponytail Fallback: Non-Official YouTube Music Thumbnail Search (Zero API Key)
    private func searchYouTubeThumbnailFallback(
        cleanTitle: String,
        cleanArt: String,
        cacheKey: String,
        completion: @escaping (Data?) -> Void
    ) {
        // Tab YouTube yang aktif sudah dicoba di awal fetchOnlineArtwork. Langsung search YouTube HTML.
        self.queryYouTubeSearchForThumbnail(cleanTitle: cleanTitle, cleanArt: cleanArt, cacheKey: cacheKey, completion: completion)
    }
    
    private func validateYouTubeVideo(
        _ id: String,
        expectedTitle: String,
        completion: @escaping (Bool) -> Void
    ) {
        let urlStr = "https://www.youtube.com/oembed?url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3D\(id)&format=json"
        guard let url = URL(string: urlStr) else { completion(false); return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 3
        URLSession.shared.dataTask(with: req) { data, resp, _ in
            guard let data = data,
                  let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let title = json["title"] as? String else { completion(false); return }
            let want = TitleMatching.core(expectedTitle)
            completion(!want.isEmpty && TitleMatching.normalize(title).contains(want))
        }.resume()
    }

    private func firstValidVideoId(
        _ ids: [String],
        index: Int,
        title: String,
        completion: @escaping (String?) -> Void
    ) {
        guard index < ids.count else { completion(nil); return }
        self.validateYouTubeVideo(ids[index], expectedTitle: title) { [weak self] ok in
            guard let self = self else { return }
            if ok {
                completion(ids[index])
            } else {
                self.firstValidVideoId(ids, index: index + 1, title: title, completion: completion)
            }
        }
    }
    
    private func queryYouTubeSearchForThumbnail(
        cleanTitle: String,
        cleanArt: String,
        cacheKey: String,
        completion: @escaping (Data?) -> Void
    ) {
        let hasArtist = !cleanArt.isEmpty && cleanArt != "System Audio" && cleanArt.lowercased() != "youtube" && cleanArt.lowercased() != "google chrome"
        let queryText = hasArtist ? "\(cleanArt) \(cleanTitle)" : cleanTitle
        guard let encoded = queryText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.youtube.com/results?search_query=\(encoded)") else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        
        var req = URLRequest(url: url)
        req.timeoutInterval = 3.5
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self = self, let data = data, let html = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            var seen = Set<String>()
            var ids: [String] = []
            if let regex = try? NSRegularExpression(pattern: #""videoId"\s*:\s*"([A-Za-z0-9_-]{11})""#) {
                for m in regex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
                    if let r = Range(m.range(at: 1), in: html) {
                        let id = String(html[r])
                        if seen.insert(id).inserted { ids.append(id) }
                        if ids.count >= 5 { break }
                    }
                }
            }
            self.firstValidVideoId(ids, index: 0, title: cleanTitle) { [weak self] validId in
                guard let self = self else { return }
                guard let validId = validId else { DispatchQueue.main.async { completion(nil) }; return }
                self.fetchYouTubeThumbnail(videoId: validId) { [weak self] ytData in
                    guard let self = self else { return }
                    if let ytData = ytData, !ytData.isEmpty {
                        self.artStore(cacheKey, ytData)
                        completion(ytData)
                    } else {
                        completion(nil)
                    }
                }
            }
        }.resume()
    }
}
