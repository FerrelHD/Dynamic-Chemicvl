import Foundation

public struct LyricLine: Identifiable, Equatable {
    public let id = UUID()
    public let timestamp: Double
    public let text: String
    
    public init(timestamp: Double, text: String) {
        self.timestamp = timestamp
        self.text = text
    }
}

public struct LyricsResult {
    public let lines: [LyricLine]
    public let isSynced: Bool

    public init(lines: [LyricLine], isSynced: Bool) {
        self.lines = lines
        self.isSynced = isSynced
    }
}

public class LyricsService {
    public static let shared = LyricsService()
    
    private var lyricsCache: [String: LyricsResult] = [:]
    private var missUntil: [String: Date] = [:]      // lagu yang pasti tidak ada di LRCLIB (disimpan sementara)
    private var inFlightCallbacks: [String: [(Result<LyricsResult, Error>) -> Void]] = [:] // antrean callback per request
    private var latestKey = ""                       // permintaan terbaru; hasil permintaan lama tidak dikirim ke UI
    private var offsets: [String: Double] = UserDefaults.standard.dictionary(forKey: "LyricsUserOffsets") as? [String: Double] ?? [:]
    private let cacheLock = NSLock()
    
    // Pre-compiled regular expressions for high-performance audio metadata parsing
    private static let bracketRegex = try? NSRegularExpression(
        pattern: #"\s*[\(\[][^\)\]]*\b(?:official|video|audio|visualizer|lyrics?|lirik|mv|m\/v|hd|4k|feat|ft|dance practice|performance video|special clip|slowed|sped\s*up|speed\s*up|reverb|nightcore|cover|unreleased|demo|acoustic|live|tiktok|terjemahan|sub\s*(?:indo|eng)|(?:indo|eng)\s*sub|color\s*coded|instrumental|karaoke|8d|prod\.?\s*(?:by)?)\b[^\)\]]*[\)\]]"#,
        options: .caseInsensitive
    )
    private static let trailingVideoRegex = try? NSRegularExpression(
        pattern: #"(?i)\s*(?:performance\s*video|music\s*video|special\s*clip|dance\s*practice|official\s*(?:music\s*video|mv|video|audio)|m\/v|mv|audio|lyrics|slowed\s*(?:[+&]\s*reverb)?|sped\s*up|speed\s*up|nightcore)\s*$"#,
        options: []
    )
    private static let koreanRegex = try? NSRegularExpression(
        pattern: #"\s*\([^)]*[\uac00-\ud7a3]+[^)]*\)"#,
        options: []
    )
    
    private static let lrcTimeTag = try? NSRegularExpression(
        pattern: #"\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]"#
    )
    private static let lrcOffsetTag = try? NSRegularExpression(
        pattern: #"^\[offset:\s*([+-]?\d+)\s*\]"#,
        options: .caseInsensitive
    )
    
    private func cachedResult(_ key: String) -> LyricsResult? {
        self.cacheLock.lock()
        defer { self.cacheLock.unlock() }
        return self.lyricsCache[key]
    }

    private func storeResult(_ key: String, _ result: LyricsResult) {
        self.cacheLock.lock()
        if self.lyricsCache.count >= 100 { self.lyricsCache.removeAll() }   // batas kecil agar memori tetap ringan
        self.lyricsCache[key] = result
        self.cacheLock.unlock()
    }
    
    private func makeURL(_ base: String, _ params: [(String, String)]) -> URL? {
        let query = params.map { key, value -> String in
            "\(key)=\(TitleMatching.urlQueryEncode(value))"
        }.joined(separator: "&")
        return URL(string: "\(base)?\(query)")
    }

    private func getJSON(_ url: URL?, _ done: @escaping (Any?) -> Void) {
        guard let url = url else { done(nil); return }
        var req = URLRequest(url: url)
        req.setValue("DynamicIslandMac/1.0 (Macintosh; Intel Mac OS X 12_7_6)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 4
        URLSession.shared.dataTask(with: req) { data, response, _ in
            guard let data = data,
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let obj = try? JSONSerialization.jsonObject(with: data) else { done(nil); return }
            done(obj)
        }.resume()
    }
    
    public static func cleanTrackTitle(_ raw: String) -> String {
        var title = raw
        
        // 1. Strip brackets and parentheses containing video/audio keywords
        if let regex = bracketRegex {
            title = regex.stringByReplacingMatches(in: title, options: [], range: NSRange(location: 0, length: title.utf16.count), withTemplate: "")
        }
        // 2. Strip trailing video keywords
        if let regex = trailingVideoRegex {
            title = regex.stringByReplacingMatches(in: title, options: [], range: NSRange(location: 0, length: title.utf16.count), withTemplate: "")
        }
        // 3. Strip non-Latin/Korean transliteration in parentheses, e.g. "(뉴진스)"
        if let regex = koreanRegex {
            title = regex.stringByReplacingMatches(in: title, options: [], range: NSRange(location: 0, length: title.utf16.count), withTemplate: "")
        }
        // Apostrof sengaja dipertahankan agar tidak merusak kata seperti "Don't"
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Offset manual per lagu
    
    /// Kunci yang sama dengan yang dipakai cache lirik, agar offset menempel ke lagu + versi (durasi) yang diputar.
    public static func trackKey(title: String, artist: String, duration: Double) -> String {
        let clean = cleanTrackTitle(title)
        let dur = (duration.isFinite && duration > 0) ? duration : 0
        return "\(clean.lowercased())|\(artist.lowercased())|\(Int(dur))"
    }
    
    public func userOffset(forKey key: String) -> Double {
        self.cacheLock.lock()
        defer { self.cacheLock.unlock() }
        return self.offsets[key] ?? 0
    }
    
    public func setUserOffset(_ value: Double, forKey key: String) {
        self.cacheLock.lock()
        if value == 0 { self.offsets[key] = nil } else { self.offsets[key] = value }
        UserDefaults.standard.set(self.offsets, forKey: "LyricsUserOffsets")
        self.cacheLock.unlock()
    }
    
    // MARK: - Pencocokan dengan skor
    
    /// Judul + artis harus cocok. Durasi hanya dipakai untuk memilih kandidat terdekat:
    /// - ada artis terverifikasi: selisih sampai 45 detik masih diterima (video sering punya intro/outro)
    /// - tanpa artis: tetap ketat (5 detik) karena buktinya lebih sedikit
    static func pickLines(_ items: [[String: Any]], title: String, artist: String, duration: Double, allowPlain: Bool = false) -> LyricsResult? {
        let wantTitle = TitleMatching.core(title)
        guard !wantTitle.isEmpty else { return nil }
        let needArtist = !artist.isEmpty
        // Tanpa artis DAN tanpa durasi tidak ada cukup bukti: lebih baik tidak cocok sama sekali.
        if !needArtist && duration <= 0 { return nil }
        let maxGap: Double = needArtist ? 45 : 5

        var bestSynced: (lines: [LyricLine], diff: Double)?
        var bestPlain: (lines: [LyricLine], diff: Double)?

        for entry in items {
            guard TitleMatching.core(entry["trackName"] as? String ?? "") == wantTitle else { continue }
            if needArtist {
                guard TitleMatching.artistsMatch(entry["artistName"] as? String ?? "", artist) else { continue }
            }
            let d = entry["duration"] as? Double ?? 0
            if !needArtist && d <= 0 { continue }
            let diff = (duration > 0 && d > 0) ? abs(d - duration) : 0
            guard diff <= maxGap else { continue }

            if let synced = entry["syncedLyrics"] as? String, !synced.isEmpty {
                let parsed = parseLRC(synced)
                if !parsed.isEmpty && (bestSynced == nil || diff < bestSynced!.diff) {
                    bestSynced = (parsed, diff)
                }
            } else if allowPlain, let plain = entry["plainLyrics"] as? String, !plain.isEmpty {
                let parsed = parsePlain(plain)
                if !parsed.isEmpty && (bestPlain == nil || diff < bestPlain!.diff) {
                    bestPlain = (parsed, diff)
                }
            }
        }

        if let chosen = bestSynced {
            return LyricsResult(lines: chosen.lines, isSynced: true)
        }
        if allowPlain, let chosen = bestPlain {
            return LyricsResult(lines: chosen.lines, isSynced: false)
        }
        return nil
    }

    static func parsePlain(_ plain: String) -> [LyricLine] {
        plain.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { LyricLine(timestamp: 0, text: $0) }
    }
    
    // MARK: - Varian query (dicoba berurutan, berhenti di yang pertama berhasil)

    private static func stripVersionTags(_ raw: String) -> String {
        var simple = cleanTrackTitle(raw)
        simple = simple.replacingOccurrences(
            of: #"(?i)\s*[\(\[]?\s*(?:feat|ft|featuring)\.?\s[^\)\]]*[\)\]]?"#,
            with: "", options: .regularExpression)
        simple = simple.replacingOccurrences(
            of: #"(?i)\s*[-–—]\s*(?:(?:\d{4}\s+)?remaster(?:ed)?(?:\s+\d{4})?|single\s+version|radio\s+edit|album\s+version|taylor'?s\s+version|mono|stereo|acoustic(?:\s+version)?|live(?:\s+.*)?|demo|slowed.*|sped\s*up.*|speed\s*up.*|remix.*|from\s+.*)$"#,
            with: "", options: .regularExpression)
        return simple.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func queryVariants(title: String, artist: String) -> [(title: String, artist: String)] {
        var out: [(title: String, artist: String)] = []
        func add(_ t: String, _ a: String) {
            let t = t.trimmingCharacters(in: .whitespacesAndNewlines)
            let a = a.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return }
            if out.contains(where: { $0.title.lowercased() == t.lowercased() && $0.artist.lowercased() == a.lowercased() }) { return }
            out.append((title: t, artist: a))
        }
        
        add(title, artist)
        let simple = stripVersionTags(title)
        add(simple, artist)
        
        // Artis pertama saja untuk "A, B" atau "A & B"
        if let first = artist.split(whereSeparator: { $0 == "," || $0 == "&" }).first {
            add(simple, String(first))
        }
        
        // Judul dan artis tertukar (upload berformat "Judul - Artis")
        if !artist.isEmpty {
            add(artist, title)
            add(stripVersionTags(artist), stripVersionTags(title))
        }
        
        return out
    }
    
    // MARK: - Fetch
    public func fetchLyrics(title: String, artist: String, duration: Double = 0,
                            completion: @escaping (Result<LyricsResult, Error>) -> Void) {
        let clean = LyricsService.cleanTrackTitle(title)
        let notFound = NSError(domain: "LyricsService", code: 404,
                               userInfo: [NSLocalizedDescriptionKey: "No lyrics found for this track"])
        guard !clean.isEmpty, clean != "No Media Playing" else { completion(.failure(notFound)); return }

        let dur = (duration.isFinite && duration > 0) ? duration : 0
        let key = LyricsService.trackKey(title: title, artist: artist, duration: dur)

        self.cacheLock.lock()
        self.latestKey = key
        if let hit = self.lyricsCache[key] {
            self.cacheLock.unlock()
            completion(.success(hit))
            return
        }
        if let until = self.missUntil[key], until > Date() {
            self.cacheLock.unlock()
            completion(.failure(notFound))
            return
        }
        if self.inFlightCallbacks[key] != nil {
            self.inFlightCallbacks[key]?.append(completion)
            self.cacheLock.unlock()
            return
        }
        self.inFlightCallbacks[key] = [completion]
        self.cacheLock.unlock()

        self.lookup(title: clean, artist: artist, duration: dur) { [weak self] result, definitive in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.cacheLock.lock()
                let callbacks = self.inFlightCallbacks.removeValue(forKey: key) ?? []
                if let res = result, !res.lines.isEmpty {
                    if self.lyricsCache.count >= 100 { self.lyricsCache.removeAll() }
                    self.lyricsCache[key] = res
                } else if definitive {
                    if self.missUntil.count > 200 { self.missUntil.removeAll() }
                    self.missUntil[key] = Date().addingTimeInterval(600)
                }
                let isLatest = (self.latestKey == key)
                self.cacheLock.unlock()
                
                guard isLatest else { return }
                let outcome: Result<LyricsResult, Error> = (result != nil && !result!.lines.isEmpty) ? .success(result!) : .failure(notFound)
                for cb in callbacks {
                    cb(outcome)
                }
            }
        }
    }

    private struct Attempt {
        let params: [(String, String)]
        let title: String
        let artist: String
    }

    /// `definitive` = true kalau LRCLIB benar-benar menjawab (bukan gagal jaringan), jadi "tidak ada" boleh diingat.
    private func lookup(title: String, artist: String, duration: Double,
                        done: @escaping (LyricsResult?, Bool) -> Void) {
        let hasArtist = !artist.isEmpty && !MediaService.isGenericArtistName(artist)
        let artistForSearch = hasArtist ? artist : ""

        var attempts: [Attempt] = []
        for v in LyricsService.queryVariants(title: title, artist: artistForSearch) {
            var p: [(String, String)] = [("track_name", v.title)]
            if !v.artist.isEmpty { p.append(("artist_name", v.artist)) }
            attempts.append(Attempt(params: p, title: v.title, artist: v.artist))
        }
        // Pencarian bebas ("artis judul"), tetap diverifikasi judul + artis.
        if hasArtist {
            let simpleTitle = LyricsService.stripVersionTags(title)
            attempts.append(Attempt(params: [("q", "\(artist) \(simpleTitle)")], title: simpleTitle, artist: artist))
            // Fallback bila nama artis ternyata nama channel uploader YouTube (hanya lolos jika durasi sangat dekat).
            if duration > 0 && !simpleTitle.isEmpty {
                attempts.append(Attempt(params: [("track_name", simpleTitle)], title: simpleTitle, artist: ""))
            }
        }

        var sawResponse = false
        var fallbackPlain: LyricsResult?

        func next(_ i: Int) {
            guard i < attempts.count else {
                done(fallbackPlain, sawResponse)
                return
            }
            let a = attempts[i]
            self.getJSON(self.makeURL("https://lrclib.net/api/search", a.params)) { json in
                if let items = json as? [[String: Any]] {
                    sawResponse = true
                    if let synced = LyricsService.pickLines(items, title: a.title, artist: a.artist, duration: duration, allowPlain: false) {
                        done(synced, true)
                        return
                    }
                    if fallbackPlain == nil {
                        fallbackPlain = LyricsService.pickLines(items, title: a.title, artist: a.artist, duration: duration, allowPlain: true)
                    }
                    NSLog("[Lyrics] miss synced title=%@ artist=%@ dur=%.0f items=%d", a.title, a.artist, duration, items.count)
                }
                next(i + 1)
            }
        }
        next(0)
    }
    
    public static func parseLRC(_ lrc: String) -> [LyricLine] {
        guard let timeTag = lrcTimeTag else { return [] }
        var offset = 0.0                       // detik; menurut spesifikasi LRC, waktu efektif = t - offset
        var lines: [LyricLine] = []

        for raw in lrc.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let ns = line as NSString
            let full = NSRange(location: 0, length: ns.length)

            if let o = lrcOffsetTag?.firstMatch(in: line, range: full) {
                offset = (Double(ns.substring(with: o.range(at: 1))) ?? 0) / 1000.0
                continue
            }

            // Kumpulkan semua tag waktu yang berurutan di awal baris: [00:12.00][00:45.00]teks
            var cursor = 0
            var times: [Double] = []
            for m in timeTag.matches(in: line, range: full) {
                guard m.range.location == cursor else { break }
                let mm = Double(ns.substring(with: m.range(at: 1))) ?? 0
                let ss = Double(ns.substring(with: m.range(at: 2))) ?? 0
                var frac = 0.0
                if m.range(at: 3).location != NSNotFound {
                    let f = ns.substring(with: m.range(at: 3))
                    frac = (Double(f) ?? 0) / pow(10, Double(f.count))
                }
                times.append(mm * 60 + ss + frac)
                cursor = m.range.location + m.range.length
            }
            guard !times.isEmpty else { continue }

            let text = ns.substring(from: cursor).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            for t in times {
                lines.append(LyricLine(timestamp: max(0, t - offset), text: text))
            }
        }
        return lines.sorted { $0.timestamp < $1.timestamp }
    }
}
