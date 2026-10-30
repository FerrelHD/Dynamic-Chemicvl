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

public class LyricsService {
    public static let shared = LyricsService()
    
    private var lyricsCache: [String: [LyricLine]] = [:]
    private let cacheLock = NSLock()
    
    // CharacterSet unreserved RFC 3986 (menjamin '&', '+', dll ter-encode aman dan tidak memotong query)
    private static let unreserved = CharacterSet(charactersIn:
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
    
    // Pre-compiled regular expressions for high-performance audio metadata parsing
    private static let bracketRegex = try? NSRegularExpression(
        pattern: #"\s*[\(\[][^\)\]]*\b(?:official|video|audio|visualizer|lyrics?|mv|m\/v|hd|4k|feat|ft|dance practice|performance video|special clip)\b[^\)\]]*[\)\]]"#,
        options: .caseInsensitive
    )
    private static let trailingVideoRegex = try? NSRegularExpression(
        pattern: #"(?i)\s*(?:performance\s*video|music\s*video|special\s*clip|dance\s*practice|official\s*(?:music\s*video|mv|video|audio)|m\/v|mv|audio|lyrics)\s*$"#,
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
    
    private func cachedLines(_ key: String) -> [LyricLine]? {
        self.cacheLock.lock()
        defer { self.cacheLock.unlock() }
        return self.lyricsCache[key]
    }

    private func storeLines(_ key: String, _ lines: [LyricLine]) {
        self.cacheLock.lock()
        self.lyricsCache[key] = lines
        self.cacheLock.unlock()
    }
    
    private func makeURL(_ base: String, _ params: [(String, String)]) -> URL? {
        let query = params.map { key, value -> String in
            let v = value.addingPercentEncoding(withAllowedCharacters: LyricsService.unreserved) ?? ""
            return "\(key)=\(v)"
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
    
    private static func bestMatch(_ items: [[String: Any]], title: String, artist: String,
                                  duration: Double, requireArtist: Bool, tolerance: Double) -> [String: Any]? {
        let wantTitle = TitleMatching.core(title)
        guard !wantTitle.isEmpty else { return nil }
        // Tanpa artis DAN tanpa durasi tidak ada cukup bukti: lebih baik tidak cocok sama sekali.
        if !requireArtist && duration <= 0 { return nil }

        var best: (item: [String: Any], diff: Double)?
        for entry in items {
            guard let synced = entry["syncedLyrics"] as? String, !synced.isEmpty else { continue }
            guard TitleMatching.core(entry["trackName"] as? String ?? "") == wantTitle else { continue }
            if requireArtist {
                guard TitleMatching.artistsMatch(entry["artistName"] as? String ?? "", artist) else { continue }
            }
            let d = entry["duration"] as? Double ?? 0
            let diff = (duration > 0 && d > 0) ? abs(d - duration) : 0
            guard diff <= tolerance else { continue }
            if let b = best, b.diff <= diff { continue }
            best = (entry, diff)
        }
        return best?.item
    }
    
    public func fetchLyrics(title: String, artist: String, duration: Double = 0,
                            completion: @escaping (Result<[LyricLine], Error>) -> Void) {
        let clean = LyricsService.cleanTrackTitle(title)
        let notFound = NSError(domain: "LyricsService", code: 404,
                               userInfo: [NSLocalizedDescriptionKey: "No lyrics found for this track"])
        guard !clean.isEmpty, clean != "No Media Playing" else { completion(.failure(notFound)); return }

        let dur = (duration.isFinite && duration > 0) ? duration : 0
        let key = "\(clean.lowercased())|\(artist.lowercased())|\(Int(dur))"
        if let hit = self.cachedLines(key) { completion(.success(hit)); return }

        self.lookup(title: clean, artist: artist, duration: dur) { [weak self] lines in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let lines = lines, !lines.isEmpty {
                    self.storeLines(key, lines)
                    completion(.success(lines))
                } else {
                    completion(.failure(notFound))
                }
            }
        }
    }

    private func lookup(title: String, artist: String, duration: Double,
                        done: @escaping ([LyricLine]?) -> Void) {
        let hasArtist = !artist.isEmpty && artist != "System Audio"

        // Deklarasi urut: search -> viaSearch -> viaGet (fungsi lokal tidak boleh saling memanggil ke depan).
        func search(withArtist: Bool, requireArtist: Bool, tolerance: Double,
                    onMiss: @escaping () -> Void) {
            var params = [("track_name", title)]
            if withArtist { params.append(("artist_name", artist)) }
            self.getJSON(self.makeURL("https://lrclib.net/api/search", params)) { json in
                let items = json as? [[String: Any]] ?? []
                if let m = LyricsService.bestMatch(items, title: title, artist: artist, duration: duration,
                                                   requireArtist: requireArtist, tolerance: tolerance),
                   let s = m["syncedLyrics"] as? String {
                    let lines = LyricsService.parseLRC(s)
                    if !lines.isEmpty { done(lines); return }
                }
                NSLog("[Lyrics] search miss title=%@ artist=%@ dur=%.0f withArtist=%d items=%d",
                      title, artist, duration, withArtist ? 1 : 0, items.count)
                onMiss()
            }
        }

        func viaSearch() {
            if hasArtist {
                search(withArtist: true, requireArtist: true, tolerance: 10) {
                    search(withArtist: false, requireArtist: false, tolerance: 3) { done(nil) }
                }
            } else {
                search(withArtist: false, requireArtist: false, tolerance: 3) { done(nil) }
            }
        }

        func viaGet() {
            guard hasArtist else { viaSearch(); return }
            var params = [("track_name", title), ("artist_name", artist)]
            if duration > 0 { params.append(("duration", String(Int(duration.rounded())))) }
            self.getJSON(self.makeURL("https://lrclib.net/api/get", params)) { json in
                // /api/get toleransi durasi ±2 detik dan fuzzy; tetap verifikasi hasilnya.
                if let obj = json as? [String: Any],
                   let m = LyricsService.bestMatch([obj], title: title, artist: artist, duration: duration,
                                                   requireArtist: true, tolerance: 5),
                   let s = m["syncedLyrics"] as? String {
                    let lines = LyricsService.parseLRC(s)
                    if !lines.isEmpty { done(lines); return }
                }
                viaSearch()
            }
        }

        viaGet()
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
