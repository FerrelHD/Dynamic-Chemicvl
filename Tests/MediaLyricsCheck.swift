import Foundation

// Self-contained runnable check for TitleMatching, MediaService metadata parsing, and LyricsService matching/fallbacks.

@main
struct MediaLyricsCheck {
    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), "FAIL: \(message)")
    }

    static func main() {
        // 1. URL query encoding must escape '&', '+', '#'
        let encoded = TitleMatching.urlQueryEncode("Simon & Garfunkel + #1")
        expect(!encoded.contains("&") && !encoded.contains("+") && !encoded.contains("#"),
               "Special URL chars must be percent-encoded, got: \(encoded)")
        expect(encoded.contains("%26") && encoded.contains("%2B") && encoded.contains("%23"),
               "Expected %26/%2B/%23 in \(encoded)")

        // 2. TitleMatching.core strips brackets, feat, and edition suffixes
        expect(TitleMatching.core("Blinding Lights - Single Version") == "blinding lights", "Strip - Single Version")
        expect(TitleMatching.core("Yellow - Remastered 2011") == "yellow", "Strip - Remastered 2011")
        expect(TitleMatching.core("Love Story (Taylor's Version)") == "love story", "Strip (Taylor's Version)")
        expect(TitleMatching.core("Song Title - Taylor's Version") == "song title", "Strip - Taylor's Version")
        expect(TitleMatching.core("Nightcall (Slowed + Reverb) [Cover]") == "nightcall", "Strip unofficial brackets")

        // 3. MediaService.splitArtistAndTitle preserves valid artist when title has edition suffix or "by"
        let taylor = MediaService.splitArtistAndTitle(rawTitle: "Love Story - Taylor's Version", rawArtist: "Taylor Swift")
        expect(taylor.artist == "Taylor Swift" && taylor.title == "Love Story - Taylor's Version",
               "Valid artist must not be overwritten by Love Story, got artist=\(taylor.artist) title=\(taylor.title)")

        let standByMe = MediaService.splitArtistAndTitle(rawTitle: "Stand by Me", rawArtist: "Ben E. King")
        expect(standByMe.artist == "Ben E. King" && standByMe.title == "Stand by Me",
               "'Stand by Me' must not split on 'by', got artist=\(standByMe.artist) title=\(standByMe.title)")

        let ytGeneric = MediaService.splitArtistAndTitle(rawTitle: "NIKI - Lowkey (Slowed + Reverb) [Lyrics]", rawArtist: "YouTube Music")
        expect(ytGeneric.artist == "NIKI" && ytGeneric.title == "Lowkey",
               "Generic YouTube Music artist should split cleanly, got artist=\(ytGeneric.artist) title=\(ytGeneric.title)")

        let ytChannel = MediaService.splitArtistAndTitle(rawTitle: "NIKI - Lowkey (Cover)", rawArtist: "CloudLyrics")
        expect(ytChannel.artist == "NIKI" && ytChannel.title == "Lowkey",
               "Channel upload 'Artist - Title' should extract NIKI and Lowkey, got artist=\(ytChannel.artist) title=\(ytChannel.title)")

        let ytUnofficialClean = MediaService.cleanVideoTitle("Glue Song (Sped Up) [Cover] (Terjemahan Indonesia)")
        expect(ytUnofficialClean == "Glue Song", "Unofficial tags must be cleaned, got: \(ytUnofficialClean)")

        // 4. LyricsService.queryVariants cleans swapped and versioned pairs
        let variants = LyricsService.queryVariants(title: "Lowkey (Slowed + Reverb)", artist: "NIKI")
        expect(variants.contains(where: { $0.title == "Lowkey" && $0.artist == "NIKI" }),
               "Variants should include cleaned title, got: \(variants)")

        // 5. LyricsService.pickLines: synced preferred over plain, channel-tolerant duration match, and plain fallback
        let mockItems: [[String: Any]] = [
            [
                "trackName": "Glue Song",
                "artistName": "beabadoobee",
                "duration": 136.0,
                "plainLyrics": "I've never known someone like you\nTangled in love"
            ]
        ]
        let plainFallback = LyricsService.pickLines(mockItems, title: "Glue Song", artist: "", duration: 138.0, allowPlain: true)
        expect(plainFallback != nil && plainFallback?.isSynced == false && plainFallback?.lines.count == 2,
               "Plain fallback with tight duration match should succeed with isSynced == false")

        let plainRejectedWhenTooFar = LyricsService.pickLines(mockItems, title: "Glue Song", artist: "", duration: 180.0, allowPlain: true)
        expect(plainRejectedWhenTooFar == nil, "Artist-less match must reject duration diff > 5s")

        let syncedPreferredItems: [[String: Any]] = [
            [
                "trackName": "Glue Song",
                "artistName": "beabadoobee",
                "duration": 136.0,
                "plainLyrics": "Plain only"
            ],
            [
                "trackName": "Glue Song",
                "artistName": "beabadoobee",
                "duration": 137.0,
                "syncedLyrics": "[00:05.00]I've never known someone like you"
            ]
        ]
        let syncedHit = LyricsService.pickLines(syncedPreferredItems, title: "Glue Song", artist: "beabadoobee", duration: 136.0, allowPlain: true)
        expect(syncedHit != nil && syncedHit?.isSynced == true && syncedHit?.lines.first?.text == "I've never known someone like you",
               "Synced lyrics must take precedence over plain lyrics")

        print("✅ All Media & Lyrics checks passed!")
    }
}
