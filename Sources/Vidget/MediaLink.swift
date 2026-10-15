import Foundation

/// Anything the widget knows how to play.
enum MediaLink: Equatable {
    case youtube(YouTubeURL.Parsed)
    /// A 40-hex Ace Stream content ID, played through a local Ace Stream engine.
    case acestream(String)

    static func parse(_ input: String) -> MediaLink? {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let id = AceStream.parse(raw) { return .acestream(id) }
        if let yt = YouTubeURL.parse(raw) { return .youtube(yt) }
        return nil
    }

    var isAceStream: Bool {
        if case .acestream = self { return true }
        return false
    }
}

enum AceStream {
    static let defaultEngine = "127.0.0.1:6878"
    private static let hashPattern = try! NSRegularExpression(pattern: "^[0-9a-fA-F]{40}$")

    /// Accepts `acestream://<hash>`, `acestream:<hash>` or a bare 40-hex hash.
    static func parse(_ raw: String) -> String? {
        var s = raw
        for prefix in ["acestream://", "acestream:"] where s.lowercased().hasPrefix(prefix) {
            s = String(s.dropFirst(prefix.count))
        }
        s = s.split(separator: "?").first.map(String.init) ?? s   // tolerate trailing params
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let hex = s.lowercased()
        return hashPattern.firstMatch(in: hex, range: NSRange(hex.startIndex..., in: hex)) != nil ? hex : nil
    }

    /// True if `raw` looks like it's *trying* to be an Ace Stream link (used to reveal the engine field).
    static func looksLikeAceLink(_ raw: String) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespaces).lowercased()
        return t.hasPrefix("acestream:") || parse(t) != nil
    }

    /// Normalises "host:port", "http://host:port", or "host" into a base URL.
    static func engineBaseURL(_ address: String) -> URL? {
        var a = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if a.isEmpty { a = defaultEngine }
        if !a.contains("://") { a = "http://" + a }
        guard var comps = URLComponents(string: a) else { return nil }
        if comps.port == nil { comps.port = 6878 }
        comps.path = ""
        return comps.url
    }

    /// HLS manifest for a content ID — WebKit plays this natively in a <video> tag.
    static func manifestURL(engine: String, id: String) -> URL? {
        guard let base = engineBaseURL(engine) else { return nil }
        var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        comps.path = "/ace/manifest.m3u8"
        comps.queryItems = [.init(name: "id", value: id)]
        return comps.url
    }

    /// Quick liveness probe against the engine's HTTP API.
    static func engineIsReachable(_ address: String) async -> Bool {
        guard let base = engineBaseURL(address) else { return false }
        var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        comps.path = "/webui/api/service"
        comps.queryItems = [.init(name: "method", value: "get_version")]
        guard let url = comps.url else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 3
        guard let (_, resp) = try? await URLSession.shared.data(for: req) else { return false }
        return (resp as? HTTPURLResponse).map { (200..<500).contains($0.statusCode) } ?? false
    }
}
