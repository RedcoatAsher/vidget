import Foundation

/// Extracts a video ID (and optional start offset) from the many shapes a YouTube link takes.
enum YouTubeURL {
    struct Parsed: Equatable {
        /// nil when the link is a playlist/album without a specific video.
        let videoID: String?
        let playlistID: String?
        let startSeconds: Int
    }

    private static let idPattern = try! NSRegularExpression(pattern: "^[A-Za-z0-9_-]{11}$")

    static func isValidID(_ s: String) -> Bool {
        idPattern.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }

    static func parse(_ input: String) -> Parsed? {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if isValidID(raw) { return Parsed(videoID: raw, playlistID: nil, startSeconds: 0) }

        // Tolerate links pasted without a scheme.
        let withScheme = raw.contains("://") ? raw : "https://" + raw
        guard let url = URL(string: withScheme),
              let host = url.host?.lowercased() else { return nil }

        let youtubeHosts = ["youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com",
                            "youtube-nocookie.com", "www.youtube-nocookie.com"]
        let isShort = host == "youtu.be" || host == "www.youtu.be"
        guard isShort || youtubeHosts.contains(host) else { return nil }

        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let query = comps?.queryItems ?? []
        func q(_ name: String) -> String? { query.first { $0.name == name }?.value }

        var id: String?
        let path = url.pathComponents.filter { $0 != "/" }

        if isShort {
            id = path.first
        } else if let v = q("v") {
            id = v
        } else if path.count >= 2, ["shorts", "embed", "live", "v", "e"].contains(path[0]) {
            id = path[1]
        }

        let playlist = q("list").flatMap { $0.isEmpty ? nil : $0 }
        let videoID = id.flatMap { isValidID($0) ? $0 : nil }
        // Need at least a video or a playlist (youtube.com/playlist?list=…, music.youtube.com/playlist?list=…).
        guard videoID != nil || playlist != nil else { return nil }

        let start = parseTime(q("t")) ?? parseTime(q("start")) ?? parseTime(url.fragment?.replacingOccurrences(of: "t=", with: "")) ?? 0
        return Parsed(videoID: videoID, playlistID: playlist, startSeconds: start)
    }

    /// Accepts "90", "90s", "1m30s", "1h2m3s".
    static func parseTime(_ s: String?) -> Int? {
        guard let s = s, !s.isEmpty else { return nil }
        if let n = Int(s) { return n }
        var total = 0, number = 0, matched = false
        for ch in s {
            if let d = ch.wholeNumberValue { number = number * 10 + d; continue }
            switch ch {
            case "h": total += number * 3600
            case "m": total += number * 60
            case "s": total += number
            default: return nil
            }
            number = 0; matched = true
        }
        return matched ? total + number : nil
    }
}
