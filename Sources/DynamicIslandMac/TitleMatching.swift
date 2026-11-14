import Foundation

public enum TitleMatching {
    // CharacterSet unreserved RFC 3986 (menjamin '&', '+', '#' ter-encode aman dan tidak memotong query URL)
    private static let unreserved = CharacterSet(charactersIn:
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")

    public static func urlQueryEncode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }

    /// Lowercase, buang diakritik, pertahankan huruf/angka dari SEMUA aksara
    /// (Latin, Hangul, Kana, dll). Jangan pakai [^a-z0-9]: judul non-Latin akan
    /// menjadi string kosong dan semuanya cocok satu sama lain.
    public static func normalize(_ s: String) -> String {
        s.lowercased()
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Inti judul: buang isi tanda kurung/siku, "feat ...", separator noise (| // • ~),
    /// dan suffix edisi/versi bertanda hubung, lalu normalisasi.
    public static func core(_ s: String) -> String {
        var t = s.replacingOccurrences(of: #"[\(\[][^\)\]]*[\)\]]"#, with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(?i)\s+(feat|ft|featuring)\.?\s.*$"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(?i)\s*(?:[|•~]|\/{1,2})\s*.*$"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(
            of: #"(?i)\s*[-–—]\s*(?:(?:\d{4}\s+)?remaster(?:ed)?(?:\s+\d{4})?|single\s+version|radio\s+edit|album\s+version|taylor'?s\s+version|explicit|clean|mono|stereo|acoustic(?:\s+version)?|live(?:\s+.*)?|demo|slowed.*|sped\s*up.*|speed\s*up.*|remix.*|instrumental|karaoke|from\s+.*)$"#,
            with: "", options: .regularExpression
        )
        let c = normalize(t)
        return c.isEmpty ? normalize(s) : c
    }

    /// Artis cocok kalau salah satu mengandung yang lain, atau jika nama kolaborasi cocok.
    public static func artistsMatch(_ a: String, _ b: String) -> Bool {
        let x = normalize(a), y = normalize(b)
        guard !x.isEmpty, !y.isEmpty else { return false }
        if x == y || x.contains(y) || y.contains(x) { return true }
        
        let seps = [" and ", " & ", ", "]
        for sep in seps {
            if a.contains(sep) {
                for part in a.components(separatedBy: sep) {
                    let np = normalize(part)
                    if !np.isEmpty && (np == y || np.contains(y) || y.contains(np)) {
                        return true
                    }
                }
            }
            if b.contains(sep) {
                for part in b.components(separatedBy: sep) {
                    let np = normalize(part)
                    if !np.isEmpty && (np == x || np.contains(x) || x.contains(np)) {
                        return true
                    }
                }
            }
        }
        return false
    }
}
