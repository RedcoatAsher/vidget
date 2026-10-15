import Foundation

/// One previously played link. Title/thumbnail arrive asynchronously from YouTube's oEmbed endpoint.
struct HistoryEntry: Codable, Identifiable, Equatable {
    var id: String { key }
    /// Dedupe key: the video ID, or the playlist ID for playlist-only links.
    let key: String
    var url: String
    var videoID: String?
    var playlistID: String?
    var aceStreamID: String?
    var startSeconds: Int
    var title: String?
    var thumbnailURL: String?
    var lastPlayed: Date

    init(link: MediaLink, url: String) {
        self.url = url
        lastPlayed = Date()
        startSeconds = 0
        switch link {
        case .youtube(let parsed):
            key = parsed.videoID ?? "list:\(parsed.playlistID ?? "")"
            videoID = parsed.videoID
            playlistID = parsed.playlistID
            startSeconds = parsed.startSeconds
            // Video thumbnails have a predictable URL; no network needed.
            if let v = parsed.videoID { thumbnailURL = "https://i.ytimg.com/vi/\(v)/mqdefault.jpg" }
        case .acestream(let id):
            key = "ace:\(id)"
            aceStreamID = id
        }
    }

    /// Rebuilds the playable link from a stored entry.
    var link: MediaLink {
        if let id = aceStreamID { return .acestream(id) }
        return .youtube(.init(videoID: videoID, playlistID: playlistID, startSeconds: startSeconds))
    }

    var isAceStream: Bool { aceStreamID != nil }

    /// What to show if the title hasn't been fetched (or couldn't be).
    var displayTitle: String {
        if let t = title, !t.isEmpty { return t }
        if let a = aceStreamID { return "Ace Stream \(a.prefix(8))…" }
        if videoID == nil, let p = playlistID { return "Playlist \(p)" }
        return url
    }
}

/// Persists the last `limit` entries in UserDefaults as JSON.
enum HistoryStore {
    static let limit = 20
    private static let key = "history"

    static func load() -> [HistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return [] }
        return list
    }

    static func save(_ list: [HistoryEntry]) {
        if let data = try? JSONEncoder().encode(Array(list.prefix(limit))) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Fetches title (and, for playlists, a thumbnail) from YouTube's oEmbed endpoint.
    static func fetchMetadata(for entry: HistoryEntry) async -> (title: String?, thumbnail: String?) {
        // oEmbed wants a canonical youtube.com URL.
        let canonical: String
        if let v = entry.videoID {
            canonical = "https://www.youtube.com/watch?v=\(v)"
        } else if let p = entry.playlistID {
            canonical = "https://www.youtube.com/playlist?list=\(p)"
        } else { return (nil, nil) }

        var comps = URLComponents(string: "https://www.youtube.com/oembed")!
        comps.queryItems = [.init(name: "url", value: canonical), .init(name: "format", value: "json")]
        guard let url = comps.url,
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return (nil, nil) }
        return (json["title"] as? String, json["thumbnail_url"] as? String)
    }
}
