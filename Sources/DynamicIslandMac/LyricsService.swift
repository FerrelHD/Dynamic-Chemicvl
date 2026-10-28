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
    
    // Pre-compiled regular expressions for high-performance audio metadata parsing
    private static let bracketRegex = try? NSRegularExpression(
        pattern: #"\s*[\(\[][^\)\]]*(?:performance|practice|dance|stage|clip|visualizer|official|video|audio|mv|lyrics?|hd|4k|m\/v|feat|ft\.)[^\)\]]*[\)\]]"#,
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
    private static let quotesRegex = try? NSRegularExpression(
        pattern: #"[\"\'\`]"#,
        options: .caseInsensitive
    )
    private static let lrcLineRegex = try? NSRegularExpression(
        pattern: #"^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$"#
    )
    
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
        // 4. Strip single and double quotes
        if let regex = quotesRegex {
            title = regex.stringByReplacingMatches(in: title, options: [], range: NSRange(location: 0, length: title.utf16.count), withTemplate: "")
        }
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public func fetchLyrics(title: String, artist: String, completion: @escaping (Result<[LyricLine], Error>) -> Void) {
        let clean = LyricsService.cleanTrackTitle(title)
        guard !clean.isEmpty && clean != "No Media Playing" else {
            completion(.failure(NSError(domain: "LyricsService", code: 400, userInfo: [NSLocalizedDescriptionKey: "No track active"])))
            return
        }
        
        let cacheKey = "\(clean.lowercased())_\(artist.lowercased())"
        if let cached = lyricsCache[cacheKey], !cached.isEmpty {
            completion(.success(cached))
            return
        }
        
        var candidates: [String] = []
        // Candidate 1: The cleaned title itself (Essential for YouTube where artist is the channel name)
        candidates.append(clean)
        
        let hasArtistInTitle = clean.lowercased().contains(artist.lowercased())
        if !hasArtistInTitle && !artist.isEmpty && artist != "System Audio" {
            candidates.append("\(clean) \(artist)")
            candidates.append("\(artist) \(clean)")
        }
        
        if clean.contains(" - ") {
            let parts = clean.components(separatedBy: " - ")
            if parts.count >= 2 {
                let p0 = parts[0].trimmingCharacters(in: .whitespaces)
                let p1 = parts[1].trimmingCharacters(in: .whitespaces)
                candidates.append("\(p0) \(p1)")
                candidates.append("\(p1) \(p0)")
                candidates.append(p1)
            }
        }
        
        if hasArtistInTitle {
            let stripped = clean.replacingOccurrences(of: artist, with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
            if !stripped.isEmpty {
                candidates.append("\(stripped) \(artist)")
            }
        }
        
        searchLRCLIB(candidates: candidates, index: 0, cacheKey: cacheKey, completion: completion)
    }
    
    private func searchLRCLIB(candidates: [String], index: Int, cacheKey: String, completion: @escaping (Result<[LyricLine], Error>) -> Void) {
        guard index < candidates.count else {
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "LyricsService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No lyrics found for this track"])))
            }
            return
        }
        
        let query = candidates[index]
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lrclib.net/api/search?q=\(encoded)") else {
            searchLRCLIB(candidates: candidates, index: index + 1, cacheKey: cacheKey, completion: completion)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("DynamicIslandMac/1.0 (Macintosh; Intel Mac OS X 12_7_6)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 5.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let data = data, error == nil,
                  let jsonArray = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]],
                  !jsonArray.isEmpty else {
                self?.searchLRCLIB(candidates: candidates, index: index + 1, cacheKey: cacheKey, completion: completion)
                return
            }
            
            // Prioritize entries with syncedLyrics
            let match = jsonArray.first(where: {
                if let s = $0["syncedLyrics"] as? String, !s.isEmpty { return true }
                return false
            }) ?? jsonArray.first!
            
            if let synced = match["syncedLyrics"] as? String, !synced.isEmpty {
                let parsed = LyricsService.parseLRC(synced)
                if !parsed.isEmpty {
                    self?.lyricsCache[cacheKey] = parsed
                    DispatchQueue.main.async { completion(.success(parsed)) }
                    return
                }
            }
            
            if let plain = match["plainLyrics"] as? String, !plain.isEmpty {
                let lines = plain.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                let parsed = lines.enumerated().map { LyricLine(timestamp: Double($0.offset * 4), text: $0.element) }
                if !parsed.isEmpty {
                    self?.lyricsCache[cacheKey] = parsed
                    DispatchQueue.main.async { completion(.success(parsed)) }
                    return
                }
            }
            
            self?.searchLRCLIB(candidates: candidates, index: index + 1, cacheKey: cacheKey, completion: completion)
        }.resume()
    }
    
    public static func parseLRC(_ lrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let rawLines = lrc.components(separatedBy: "\n")
        guard let regex = lrcLineRegex else { return [] }
        
        for raw in rawLines {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let range = NSRange(location: 0, length: trimmed.utf16.count)
            if let match = regex.firstMatch(in: trimmed, options: [], range: range) {
                if let minRange = Range(match.range(at: 1), in: trimmed),
                   let secRange = Range(match.range(at: 2), in: trimmed),
                   let msRange = Range(match.range(at: 3), in: trimmed),
                   let textRange = Range(match.range(at: 4), in: trimmed) {
                    let min = Double(trimmed[minRange]) ?? 0
                    let sec = Double(trimmed[secRange]) ?? 0
                    let msStr = String(trimmed[msRange])
                    let ms = (Double(msStr) ?? 0) / (msStr.count == 3 ? 1000.0 : 100.0)
                    let text = String(trimmed[textRange]).trimmingCharacters(in: .whitespaces)
                    if !text.isEmpty {
                        lines.append(LyricLine(timestamp: min * 60 + sec + ms, text: text))
                    }
                }
            }
        }
        return lines.sorted(by: { $0.timestamp < $1.timestamp })
    }
}

