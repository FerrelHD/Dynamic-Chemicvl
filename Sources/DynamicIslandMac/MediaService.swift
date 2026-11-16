import Foundation
import AppKit

// MARK: - YouTube tab models (hasil baca tab browser)

/// Metadata yang diisi YouTube / YouTube Music sendiri lewat navigator.mediaSession & DOM player.
struct YouTubeSession {
    let title: String
    let artist: String
    let artworkURL: String?
    let videoId: String?
    let isPlaying: Bool
}

struct YouTubeTab {
    let videoId: String?
    let isMusic: Bool
    let tabTitle: String
    let session: YouTubeSession?   // nil kalau "Allow JavaScript from Apple Events" belum aktif
}

public class MediaService {
    public static let shared = MediaService()
    
    // Tipe fungsi C dari MediaRemote.framework
    private typealias MRGetNowPlayingInfoFn = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias MRSendCommandFn = @convention(c) (Int, AnyObject?) -> Bool
    private typealias MRSetElapsedTimeFn = @convention(c) (Double) -> Void
    
    private var getNowPlayingInfoPtr: MRGetNowPlayingInfoFn?
    private var sendCommandPtr: MRSendCommandFn?
    private var setElapsedTimePtr: MRSetElapsedTimeFn?
    
    private var pollingTimer: DispatchSourceTimer?
    private let queryQueue = DispatchQueue(label: "com.dynamicisland.mediaquery", qos: .utility)
    
    // Cache gambar: NSCache otomatis membuang yang lama (maks 40 gambar) dan ikut dikosongkan saat memori sempit.
    private let artCache: NSCache<NSString, NSData> = {
        let c = NSCache<NSString, NSData>()
        c.countLimit = 40
        return c
    }()
    private func artCached(_ key: String) -> Data? {
        artCache.object(forKey: key as NSString).map { $0 as Data }
    }
    private func artStore(_ key: String, _ data: Data) {
        artCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
    }
    
    // Status pencarian cover: cegah pencarian ganda untuk lagu yang sama dan jangan ulang terus kalau baru saja gagal.
    private let artStateLock = NSLock()
    private var artInFlight = Set<String>()
    private var artMissUntil: [String: Date] = [:]
    private var latestArtKey = ""
    
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
    
    // MARK: - Metadata Sanitizers
    public static func cleanVideoTitle(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let badgeRegex = try? NSRegularExpression(pattern: "^\\([0-9]+\\)\\s*") {
            let range = NSRange(s.startIndex..., in: s)
            s = badgeRegex.stringByReplacingMatches(in: s, options: [], range: range, withTemplate: "")
        }
        
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
        
        let sepNoise = #"(?i)\s*(?:[|•~]|\/{1,2})\s*(?:official|music|video|audio|lyric|lyrics|lirik|visualizer|mv|m\/v|klip|live|session|acoustic|slowed|sped\s*up|speed\s*up|nightcore|cover|unreleased|terjemahan|sub\s*(?:indo|eng)).*$"#
        s = s.replacingOccurrences(of: sepNoise, with: "", options: .regularExpression)
        
        let bracketNoise = #"(?i)\s*[\(\[]\s*(?:official\s+)?(?:(?:music|lyric|lyrics|performance|special)\s+)?(?:video|audio|visualizer|lyric(?:s)?|lirik|mv|m\/v|hd|4k(?:\s*60fps)?|remastered(?:\s+\d{4})?|live|session|acoustic|clip|klip|sped\s*up|speed\s*up|slowed(?:\s*[+&]\s*reverb)?|reverb|nightcore|8d(?:\s+audio)?|bass\s*boosted|cover(?:\s+by\b.*)?|unreleased|demo|full\s+(?:version|audio)|color\s+coded.*|terjemahan.*|(?:indo|eng)\s+sub.*|sub\s+(?:indo|eng).*|instrumental|karaoke|prod\.?\s*(?:by\b)?.*|tiktok(?:\s+version)?|remix(?:\s+.*)?).*?[\)\]]"#
        s = s.replacingOccurrences(of: bracketNoise, with: "", options: .regularExpression)
        
        let trailingNoise = #"(?i)\s+(?:(?:official\s+)?(?:music\s+)?(?:video|audio|visualizer|lyric(?:s)?\s+video|video\s+klip|lirik)|slowed\s*(?:[+&]\s*reverb)?|sped\s*up|speed\s*up|nightcore)$"#
        s = s.replacingOccurrences(of: trailingNoise, with: "", options: .regularExpression)
        
        let noiseTags = [
            "| VEVO", "(VEVO)", "[VEVO]"
        ]
        for tag in noiseTags {
            if let r = s.range(of: tag, options: .caseInsensitive) {
                s.removeSubrange(r)
            }
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isEditionSuffix(_ s: String) -> Bool {
        let pattern = #"(?i)^(?:(?:\d{4}\s+)?remaster(?:ed)?(?:\s+\d{4})?|single\s+version|radio\s+edit|album\s+version|taylor'?s\s+version|explicit|clean|mono|stereo|acoustic(?:\s+version)?|live(?:\s+.*)?|demo|slowed.*|sped\s*up.*|speed\s*up.*|remix.*|instrumental|karaoke|intro|outro|interlude|p(?:ar)?t\.?\s*\d+.*|from\s+.*|ost\b.*)$"#
        return s.trimmingCharacters(in: .whitespacesAndNewlines).range(of: pattern, options: .regularExpression) != nil
    }

    public static func cleanArtistName(_ raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let garbageSuffixes = [" - Topic", "- Topic", "-Topic", " – Topic", " — Topic", " Topic"]
        for suffix in garbageSuffixes {
            if cleaned.hasSuffix(suffix) {
                cleaned = String(cleaned.dropLast(suffix.count))
            }
        }
        
        // Strip trailing channel tags like "Official", "Records", "VEVO"
        cleaned = cleaned.replacingOccurrences(of: #"(?i)\s*(?:official|records|recordings|entertainment|media|channel|studios?|music)$"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"(?i)vevo$"#, with: "", options: .regularExpression)
        
        let patterns = [
            " (Official Audio)", " (Official Video)", " (Official Music Video)", " (Lyric Video)", " (Audio)",
            " [Official Audio]", " [Official Video]", " [Official Music Video]", " [Lyric Video]", " [Audio]"
        ]
        for p in patterns {
            cleaned = cleaned.replacingOccurrences(of: p, with: "", options: .caseInsensitive)
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func isGenericArtistName(_ raw: String) -> Bool {
        let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let generic = [
            "system audio", "youtube", "youtube music", "google chrome", "chrome",
            "safari", "arc", "brave", "brave browser", "microsoft edge", "edge"
        ]
        return lower.isEmpty || generic.contains(lower)
    }

    public static func splitArtistAndTitle(rawTitle: String, rawArtist: String) -> (artist: String, title: String) {
        let preCleanedTitle = cleanVideoTitle(rawTitle)
        var artist = cleanArtistName(rawArtist)
        var title = preCleanedTitle
        
        let isGenericArtist = isGenericArtistName(artist)
        
        // Format 1: "Artist - Song Title"
        var found = false
        for sep in [" - ", " – ", " — "] {
            if preCleanedTitle.contains(sep) {
                let parts = preCleanedTitle.components(separatedBy: sep)
                if parts.count >= 2 {
                    let aPart = cleanArtistName(cleanVideoTitle(parts[0]))
                    let tPart = cleanVideoTitle(parts[1...].joined(separator: sep))
                    if !aPart.isEmpty && !tPart.isEmpty {
                        if !isGenericArtist && isEditionSuffix(tPart) {
                            // Jangan pecah judul resmi seperti "Love Story - Taylor's Version" saat artis sudah valid
                            found = true
                        } else if !isGenericArtist && TitleMatching.artistsMatch(aPart, artist) {
                            title = tPart
                            found = true
                        } else if !isGenericArtist && TitleMatching.artistsMatch(tPart, artist) {
                            title = aPart
                            found = true
                        } else {
                            title = tPart
                            artist = aPart
                            found = true
                        }
                        break
                    }
                }
            }
        }
        
        // Format 2: "Song Title by Artist" (hanya jika artis generik atau cocok dengan sisi kanan, agar judul seperti "Stand by Me" aman)
        if !found && title.contains(" by ") {
            let parts = title.components(separatedBy: " by ")
            if parts.count >= 2 {
                let tPart = cleanVideoTitle(parts[0])
                let aPart = cleanArtistName(cleanVideoTitle(parts[1...].joined(separator: " by ")))
                if !tPart.isEmpty && !aPart.isEmpty && (isGenericArtist || TitleMatching.artistsMatch(aPart, artist)) {
                    title = tPart
                    artist = aPart
                }
            }
        }
        
        let finalArtist = artist.isEmpty ? (isGenericArtist ? "System Audio" : cleanArtistName(rawArtist)) : artist
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
        guard pollingTimer == nil else { return }
        
        let timer = DispatchSource.makeTimerSource(queue: queryQueue)
        timer.schedule(deadline: .now(), repeating: 1.0, leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            self?.fetchMediaInfo(completion: onChange)
        }
        timer.resume()
        self.pollingTimer = timer
    }
    
    public func stopMonitoring() {
        pollingTimer?.cancel()
        pollingTimer = nil
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
    
    // MARK: - Online Artwork
    public func fetchOnlineArtwork(
        title: String,
        artist: String,
        album: String = "",
        duration: Double = 0,
        ignoreMissCache: Bool = false,
        completion: @escaping (Data?) -> Void
    ) {
        let (cleanArt, clean) = MediaService.splitArtistAndTitle(rawTitle: title, rawArtist: artist)
        guard !clean.isEmpty && clean != "No Media Playing" else { completion(nil); return }
        let cacheKey = "\(clean.lowercased())_\(cleanArt.lowercased())_\(album.lowercased())"
        if let cached = self.artCached(cacheKey) { completion(cached); return }

        self.artStateLock.lock()
        self.latestArtKey = cacheKey
        if !ignoreMissCache, let until = self.artMissUntil[cacheKey], until > Date() {
            self.artStateLock.unlock()
            completion(nil)
            return
        }
        if self.artInFlight.contains(cacheKey) {
            self.artStateLock.unlock()
            return
        }
        self.artInFlight.insert(cacheKey)
        self.artStateLock.unlock()

        let finish: (Data?) -> Void = { [weak self] data in
            guard let self = self else { return }
            self.artStateLock.lock()
            self.artInFlight.remove(cacheKey)
            if data == nil {
                if self.artMissUntil.count > 200 { self.artMissUntil.removeAll() }
                self.artMissUntil[cacheKey] = Date().addingTimeInterval(20)
            }
            let isLatest = (self.latestArtKey == cacheKey)
            self.artStateLock.unlock()
            guard isLatest else { return }
            DispatchQueue.main.async { completion(data) }
        }

        MediaService.appleScriptQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 1. Spotify desktop (kalau sedang jalan): URL resmi dari Spotify
            if MediaService.isSpotifyRunning(),
               let spotifyArtUrl = MediaService.getSpotifyArtworkURL(),
               let url = URL(string: spotifyArtUrl) {
                self.downloadImage(url) { [weak self] data in
                    guard let self = self else { return }
                    if let data = data {
                        self.artStore(cacheKey, data)
                        finish(data)
                    } else {
                        self.proceedWithBrowserAndiTunes(clean: clean, cleanArt: cleanArt, album: album, duration: duration, cacheKey: cacheKey, completion: finish)
                    }
                }
                return
            }
            
            self.proceedWithBrowserAndiTunes(clean: clean, cleanArt: cleanArt, album: album, duration: duration, cacheKey: cacheKey, completion: finish)
        }
    }

    private func downloadImage(_ url: URL, timeout: TimeInterval = 4, completion: @escaping (Data?) -> Void) {
        var req = URLRequest(url: url)
        req.timeoutInterval = timeout
        URLSession.shared.dataTask(with: req) { data, resp, _ in
            if let http = resp as? HTTPURLResponse, http.statusCode == 200, let data = data, !data.isEmpty {
                completion(data)
            } else {
                completion(nil)
            }
        }.resume()
    }

    private func proceedWithBrowserAndiTunes(
        clean: String,
        cleanArt: String,
        album: String,
        duration: Double,
        cacheKey: String,
        completion: @escaping (Data?) -> Void
    ) {
        MediaService.appleScriptQueue.async { [weak self] in
            guard let self = self else { return }
            let tab = MediaService.findYouTubeTab(matching: clean, artist: cleanArt)

            let fallback: () -> Void = { [weak self] in
                self?.thumbnailOrSearch(tab: tab, clean: clean, cleanArt: cleanArt, album: album,
                                        duration: duration, cacheKey: cacheKey, completion: completion)
            }

            // 2. Gambar yang diberikan YouTube Music sendiri (sudah terverifikasi cocok dengan judul lagu)
            guard let artString = tab?.session?.artworkURL,
                  let url = URL(string: MediaService.upgradedArtworkURL(artString)) else {
                fallback()
                return
            }

            self.downloadImage(url) { [weak self] data in
                guard let self = self else { return }
                guard let data = data else { fallback(); return }
                let square = MediaService.squareCropped(data)
                self.artStore(cacheKey, square)
                completion(square)
            }
        }
    }

    // 3. Thumbnail video dari tab yang cocok (dipotong jadi kotak), kalau tidak ada -> 4. Deezer lalu iTunes
    private func thumbnailOrSearch(
        tab: YouTubeTab?,
        clean: String,
        cleanArt: String,
        album: String,
        duration: Double,
        cacheKey: String,
        completion: @escaping (Data?) -> Void
    ) {
        guard let id = tab?.videoId else {
            self.beginVerifiedSearch(clean: clean, cleanArt: cleanArt, album: album,
                                     duration: duration, cacheKey: cacheKey, completion: completion)
            return
        }
        let ytKey = "yt_\(id)"
        if let c = self.artCached(ytKey) {
            self.artStore(cacheKey, c)
            completion(c)
            return
        }
        self.fetchYouTubeThumbnail(videoId: id) { [weak self] data in
            guard let self = self else { return }
            guard let data = data, !data.isEmpty else {
                self.beginVerifiedSearch(clean: clean, cleanArt: cleanArt, album: album,
                                         duration: duration, cacheKey: cacheKey, completion: completion)
                return
            }
            DispatchQueue.global(qos: .utility).async {
                let square = MediaService.squareCropped(data)
                self.artStore(ytKey, square)
                self.artStore(cacheKey, square)
                completion(square)
            }
        }
    }

    /// YouTube Music memberi URL gambar kecil (mis. `=w60-h60-l90-rj`). Naikkan ke 600px.
    private static func upgradedArtworkURL(_ s: String) -> String {
        guard s.contains("googleusercontent.com") || s.contains("ggpht.com") else { return s }
        return s.replacingOccurrences(of: #"=(?:w\d+-h\d+|s\d+)[-\w]*$"#, with: "=w600-h600-l90-rj", options: .regularExpression)
    }

    /// Potong tengah jadi persegi. Thumbnail 4:3 (hqdefault) dibuang dulu garis hitam atas-bawahnya.
    private static func squareCropped(_ data: Data) -> Data {
        guard let img = NSImage(data: data),
              let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return data }
        let w = cg.width, h = cg.height
        guard w > 0, h > 0, w != h else { return data }

        let ratio = Double(w) / Double(h)
        let letterboxed = ratio > 1.30 && ratio < 1.36          // 4:3 berisi video 16:9 + bar hitam
        let contentH = letterboxed ? Int(Double(w) * 9.0 / 16.0) : h
        let contentY = (h - contentH) / 2
        let side = min(w, contentH)
        let rect = CGRect(x: (w - side) / 2, y: contentY + (contentH - side) / 2, width: side, height: side)

        guard let cropped = cg.cropping(to: rect) else { return data }
        let rep = NSBitmapImageRep(cgImage: cropped)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) ?? data
    }
    
    // MARK: - Spotify Artwork
    public static func isSpotifyRunning() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
    }
    
    public static func getSpotifyArtworkURL() -> String? {
        guard isSpotifyRunning() else { return nil }
        let script = """
        tell application "Spotify"
            if player state is playing then
                return artwork url of current track
            end if
        end tell
        """
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return nil }
        let res = appleScript.executeAndReturnError(&error).stringValue ?? ""
        if error != nil || res.isEmpty || !res.hasPrefix("http") { return nil }
        return res
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
        func appendCandidate(_ q: String) {
            let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !candidates.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
            candidates.append(trimmed)
        }

        let hasValidArtist = !cleanArt.isEmpty && !MediaService.isGenericArtistName(cleanArt)
        let strippedFeat = clean.replacingOccurrences(of: "(?i)\\s*(?:ft|feat|featuring)\\.?\\s+.*", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        let coreTitle = TitleMatching.core(clean)

        if hasValidArtist {
            appendCandidate("\(cleanArt) \(clean)")
            if !strippedFeat.isEmpty { appendCandidate("\(cleanArt) \(strippedFeat)") }
            appendCandidate("\(clean) \(cleanArt)")
        }
        if !album.isEmpty && album != "System Audio" {
            if hasValidArtist { appendCandidate("\(cleanArt) \(clean) \(album)") }
            appendCandidate("\(clean) \(album)")
        }
        appendCandidate(clean)
        if !strippedFeat.isEmpty { appendCandidate(strippedFeat) }
        if !coreTitle.isEmpty { appendCandidate(coreTitle) }

        searchDeezerArtwork(candidates: candidates, index: 0, cleanTitle: clean, cleanArt: cleanArt, duration: duration, cacheKey: cacheKey, onMiss: { [weak self] in
            self?.searchVerifiedArtwork(candidates: candidates, index: 0, cleanTitle: clean, cleanArt: cleanArt, album: album, duration: duration, cacheKey: cacheKey, completion: completion)
        }, completion: completion)
    }
    
    // MARK: - YouTube / YouTube Music tab reader (Chrome, Brave, Arc, Edge, Safari)
    private static let browsers: [(bundleID: String, appName: String, titleProp: String, isSafari: Bool)] = [
        ("com.google.Chrome", "Google Chrome", "title", false),
        ("com.apple.Safari", "Safari", "name", true),
        ("company.thebrowser.Arc", "Arc", "title", false),
        ("com.brave.Browser", "Brave Browser", "title", false),
        ("com.microsoft.edgemac", "Microsoft Edge", "title", false),
        ("com.google.Chrome.canary", "Google Chrome Canary", "title", false)
    ]
    
    // Catatan: gunakan single-quote saja di dalam JS agar aman di-embed ke string AppleScript.
    private static let sessionJS = "(function(){var m=navigator.mediaSession&&navigator.mediaSession.metadata;var v=document.querySelector('video');var a=m&&m.artwork&&m.artwork.length?m.artwork[m.artwork.length-1].src:'';if(!a){var yi=document.querySelector('ytmusic-player-bar img.image');if(yi&&yi.src&&yi.src.indexOf('http')===0)a=yi.src;}var u='';try{var qs=new URLSearchParams(location.search);u=qs.get('v')||'';}catch(e){}if(!u){var tl=document.querySelector('ytmusic-player-bar a.ytp-title-link,a.ytp-title-link');if(tl&&tl.href){var x=tl.href.match(/[?&]v=([^&#]+)/);if(x)u=x[1];}}if(!u){var wf=document.querySelector('ytd-watch-flexy');if(wf)u=wf.getAttribute('video-id')||'';}return JSON.stringify({t:m?m.title:'',ar:m?m.artist:'',art:a,vid:u,pl:v?!v.paused:false})})()"
    
    private static func parseSession(_ json: String) -> YouTubeSession? {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let art = o["art"] as? String ?? ""
        let vid = (o["vid"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return YouTubeSession(
            title: o["t"] as? String ?? "",
            artist: o["ar"] as? String ?? "",
            artworkURL: art.hasPrefix("http") ? art : nil,
            videoId: vid.isEmpty ? nil : vid,
            isPlaying: o["pl"] as? Bool ?? false
        )
    }
    
    private static func videoId(from url: URL) -> String? {
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let v = comps.queryItems?.first(where: { $0.name == "v" })?.value, !v.isEmpty {
            return v
        }
        if url.host?.contains("youtu.be") == true {
            let id = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return id.isEmpty ? nil : id
        }
        if url.path.hasPrefix("/shorts/") {
            let id = url.path.replacingOccurrences(of: "/shorts/", with: "")
            return id.isEmpty ? nil : id
        }
        return nil
    }
    
    static func findYouTubeTab(matching trackTitle: String, artist: String = "") -> YouTubeTab? {
        let wantTitle = TitleMatching.core(trackTitle)
        guard !wantTitle.isEmpty else { return nil }
        let wantArtist = TitleMatching.normalize(artist)
        let isGenericArtist = MediaService.isGenericArtistName(artist)
        
        let delim = "::NOTCH_DELIM::"
        
        for b in browsers {
            guard !NSRunningApplication.runningApplications(withBundleIdentifier: b.bundleID).isEmpty else { continue }
            
            let runJS = b.isSafari
                ? "do JavaScript \"\(sessionJS)\" in (tab i of w)"
                : "execute (tab i of w) javascript \"\(sessionJS)\""
            
            let script = """
            tell application "\(b.appName)"
                set out to ""
                repeat with w in windows
                    set urls to URL of tabs of w
                    set titles to \(b.titleProp) of tabs of w
                    repeat with i from 1 to count of urls
                        set u to item i of urls
                        if u contains "youtube.com" or u contains "youtu.be" then
                            set js to ""
                            try
                                set js to \(runJS)
                            end try
                            if js is missing value then set js to ""
                            set out to out & u & "\(delim)" & (item i of titles) & "\(delim)" & js & linefeed
                        end if
                    end repeat
                end repeat
                return out
            end tell
            """
            
            var error: NSDictionary?
            guard let appleScript = NSAppleScript(source: script) else { continue }
            let output = appleScript.executeAndReturnError(&error).stringValue ?? ""
            if error != nil || output.isEmpty { continue }
            
            var tabs: [YouTubeTab] = []
            for line in output.components(separatedBy: "\n") {
                let parts = line.components(separatedBy: delim)
                guard parts.count >= 2, let url = URL(string: parts[0]) else { continue }
                let session = parts.count >= 3 ? parseSession(parts[2]) : nil
                tabs.append(YouTubeTab(
                    videoId: videoId(from: url) ?? session?.videoId,
                    isMusic: url.host?.contains("music.youtube.com") == true,
                    tabTitle: parts[1],
                    session: session
                ))
            }
            if tabs.isEmpty { continue }
            if tabs.allSatisfy({ $0.session == nil }) {
                NSLog("[Media] Tab YouTube ditemukan di %@ tapi data mediaSession kosong. Aktifkan 'Allow JavaScript from Apple Events' di menu browser.", b.appName)
            }
            
            let verified = tabs.filter { t in
                if let s = t.session {
                    let sCore = TitleMatching.core(s.title)
                    let sNorm = TitleMatching.normalize(s.title)
                    let titleOk = (sCore == wantTitle || sNorm.contains(wantTitle))
                    if titleOk {
                        if isGenericArtist || wantArtist.isEmpty || s.artist.isEmpty { return true }
                        return TitleMatching.artistsMatch(s.artist, artist) || TitleMatching.normalize(t.tabTitle).contains(wantArtist)
                    }
                    return false
                }
                let normTab = TitleMatching.normalize(t.tabTitle)
                if normTab.contains(wantTitle) || (!wantTitle.isEmpty && wantTitle.contains(normTab)) {
                    return true
                }
                if !isGenericArtist && !wantArtist.isEmpty && normTab.contains(wantArtist) {
                    return true
                }
                return false
            }
            if let best = verified.first(where: { $0.session?.isPlaying == true }) ?? verified.first {
                return best
            }
            
            // Fallback for background / minimized tabs where title is generic (e.g. "YouTube Music" or "YouTube")
            let genericTitles = ["youtube music", "youtube"]
            let genericTabs = tabs.filter { t in
                let norm = TitleMatching.normalize(t.tabTitle)
                let hasMedia = (t.videoId != nil || t.session?.artworkURL != nil)
                return genericTitles.contains(norm) && hasMedia
            }
            if let playingMusic = genericTabs.first(where: { $0.isMusic && $0.session?.isPlaying == true })
                ?? genericTabs.first(where: { $0.isMusic }) {
                return playingMusic
            }
            if tabs.count == 1, let single = tabs.first,
               (single.videoId != nil || single.session?.artworkURL != nil),
               (single.session?.isPlaying == true || single.isMusic || isGenericArtist) {
                return single
            }
        }
        return nil
    }
    
    public static func extractActiveYouTubeVideoId(matching trackTitle: String) -> String? {
        findYouTubeTab(matching: trackTitle)?.videoId
    }
    
    public func fetchYouTubeThumbnail(videoId: String, completion: @escaping (Data?) -> Void) {
        let maxresUrl = URL(string: "https://img.youtube.com/vi/\(videoId)/maxresdefault.jpg")!
        let hqUrl = URL(string: "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg")!
        
        var req = URLRequest(url: maxresUrl)
        req.timeoutInterval = 3.0
        
        URLSession.shared.dataTask(with: req) { data, resp, _ in
            if let http = resp as? HTTPURLResponse, http.statusCode == 200, let data = data, data.count > 1000 {
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
    
    private struct CatalogCandidate {
        let title: String
        let artist: String
        let durationSeconds: Double
        let artworkURL: String
    }

    private static func pickCatalogArtworkURL(
        from items: [CatalogCandidate],
        cleanTitle: String,
        cleanArt: String,
        duration: Double
    ) -> String? {
        let wantTitle = TitleMatching.core(cleanTitle)
        guard !wantTitle.isEmpty else { return nil }
        let wantArtist = TitleMatching.normalize(cleanArt)
        let isGenericArtist = MediaService.isGenericArtistName(cleanArt)

        // Pass 1: Cocok judul + artis (atau generic artist dengan durasi terverifikasi)
        for item in items where !item.artworkURL.isEmpty {
            let itemCoreTitle = TitleMatching.core(item.title)
            let normalTitleMatch = (itemCoreTitle == wantTitle)
            let normalArtistMatch = isGenericArtist ? true : TitleMatching.artistsMatch(item.artist, cleanArt)
            let invertedTitleMatch = !isGenericArtist && (itemCoreTitle == wantArtist)
            let invertedArtistMatch = !isGenericArtist && TitleMatching.artistsMatch(item.artist, cleanTitle)

            guard (normalTitleMatch && normalArtistMatch) || (invertedTitleMatch && invertedArtistMatch) else { continue }
            if isGenericArtist && duration <= 0 { continue }

            let tolerance: Double = isGenericArtist ? 10 : 75
            if duration > 0, item.durationSeconds > 0, abs(item.durationSeconds - duration) > tolerance { continue }
            return item.artworkURL
        }

        // Pass 2: Fallback saat artist berasal dari channel uploader YouTube (wajib judul inti persis + durasi sangat ketat)
        if !isGenericArtist && duration > 0 {
            for item in items where !item.artworkURL.isEmpty && item.durationSeconds > 0 {
                if TitleMatching.core(item.title) == wantTitle && abs(item.durationSeconds - duration) <= 4.0 {
                    return item.artworkURL
                }
            }
        }
        return nil
    }

    // MARK: - iTunes Search
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
            DispatchQueue.main.async { completion(nil) }
            return
        }
        
        let rawQuery = candidates[index]
        let query = rawQuery.replacingOccurrences(of: " - ", with: " ")
            .replacingOccurrences(of: " – ", with: " ")
            .replacingOccurrences(of: " — ", with: " ")
            
        let encoded = TitleMatching.urlQueryEncode(query)
        guard !encoded.isEmpty,
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=8") else {
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

            let mapped: [CatalogCandidate] = results.compactMap { item in
                guard let artUrlStr = item["artworkUrl100"] as? String, !artUrlStr.isEmpty else { return nil }
                return CatalogCandidate(
                    title: item["trackName"] as? String ?? "",
                    artist: item["artistName"] as? String ?? "",
                    durationSeconds: ((item["trackTimeMillis"] as? Double) ?? 0) / 1000.0,
                    artworkURL: artUrlStr.replacingOccurrences(of: "100x100bb.jpg", with: "600x600bb.jpg")
                )
            }

            guard let hdArtUrlStr = MediaService.pickCatalogArtworkURL(from: mapped, cleanTitle: cleanTitle, cleanArt: cleanArt, duration: duration),
                  let hdUrl = URL(string: hdArtUrlStr) else {
                self.searchVerifiedArtwork(candidates: candidates, index: index + 1, cleanTitle: cleanTitle, cleanArt: cleanArt, album: album, duration: duration, cacheKey: cacheKey, completion: completion)
                return
            }
            
            self.downloadImage(hdUrl) { [weak self] imgData in
                guard let self = self else { return }
                if let imgData = imgData {
                    self.artStore(cacheKey, imgData)
                    DispatchQueue.main.async { completion(imgData) }
                } else {
                    self.searchVerifiedArtwork(candidates: candidates, index: index + 1, cleanTitle: cleanTitle, cleanArt: cleanArt, album: album, duration: duration, cacheKey: cacheKey, completion: completion)
                }
            }
        }.resume()
    }
    
    // MARK: - Deezer Search
    private func searchDeezerArtwork(
        candidates: [String],
        index: Int,
        cleanTitle: String,
        cleanArt: String,
        duration: Double,
        cacheKey: String,
        onMiss: @escaping () -> Void,
        completion: @escaping (Data?) -> Void
    ) {
        guard index < candidates.count else {
            onMiss()
            return
        }

        let query = candidates[index]
        let encoded = TitleMatching.urlQueryEncode(query)
        guard !encoded.isEmpty,
              let url = URL(string: "https://api.deezer.com/search?q=\(encoded)&limit=10") else {
            self.searchDeezerArtwork(candidates: candidates, index: index + 1, cleanTitle: cleanTitle, cleanArt: cleanArt, duration: duration, cacheKey: cacheKey, onMiss: onMiss, completion: completion)
            return
        }
        
        var req = URLRequest(url: url)
        req.timeoutInterval = 3.5
        
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self = self,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["data"] as? [[String: Any]], !items.isEmpty else {
                self?.searchDeezerArtwork(candidates: candidates, index: index + 1, cleanTitle: cleanTitle, cleanArt: cleanArt, duration: duration, cacheKey: cacheKey, onMiss: onMiss, completion: completion)
                return
            }

            let mapped: [CatalogCandidate] = items.compactMap { item in
                let artistDict = item["artist"] as? [String: Any]
                let albumDict = item["album"] as? [String: Any]
                let cover = (albumDict?["cover_xl"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                    ?? (albumDict?["cover_big"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                guard let coverStr = cover else { return nil }
                return CatalogCandidate(
                    title: item["title"] as? String ?? "",
                    artist: artistDict?["name"] as? String ?? "",
                    durationSeconds: item["duration"] as? Double ?? 0,
                    artworkURL: coverStr
                )
            }

            guard let coverStr = MediaService.pickCatalogArtworkURL(from: mapped, cleanTitle: cleanTitle, cleanArt: cleanArt, duration: duration),
                  let coverUrl = URL(string: coverStr) else {
                self.searchDeezerArtwork(candidates: candidates, index: index + 1, cleanTitle: cleanTitle, cleanArt: cleanArt, duration: duration, cacheKey: cacheKey, onMiss: onMiss, completion: completion)
                return
            }
            
            self.downloadImage(coverUrl, timeout: 3.5) { [weak self] imgData in
                guard let self = self else { return }
                if let imgData = imgData {
                    self.artStore(cacheKey, imgData)
                    DispatchQueue.main.async { completion(imgData) }
                } else {
                    self.searchDeezerArtwork(candidates: candidates, index: index + 1, cleanTitle: cleanTitle, cleanArt: cleanArt, duration: duration, cacheKey: cacheKey, onMiss: onMiss, completion: completion)
                }
            }
        }.resume()
    }
}
