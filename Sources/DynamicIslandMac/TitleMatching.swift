import Foundation

public enum TitleMatching {
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

    /// Inti judul: buang isi tanda kurung/siku dan "feat ...", lalu normalisasi.
    public static func core(_ s: String) -> String {
        var t = s.replacingOccurrences(of: #"[\(\[][^\)\]]*[\)\]]"#, with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(?i)\s+(feat|ft|featuring)\.?\s.*$"#, with: "", options: .regularExpression)
        let c = normalize(t)
        return c.isEmpty ? normalize(s) : c
    }

    /// Artis cocok kalau salah satu mengandung yang lain. String kosong tidak pernah cocok.
    public static func artistsMatch(_ a: String, _ b: String) -> Bool {
        let x = normalize(a), y = normalize(b)
        guard !x.isEmpty, !y.isEmpty else { return false }
        return x.contains(y) || y.contains(x)
    }
}
