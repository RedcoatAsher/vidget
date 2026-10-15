import Foundation

/// Bits shared between the app and the WidgetKit extension.
enum VidgetShared {
    /// macOS app-group id: <Team ID>.<identifier>. Both targets carry it in their entitlements.
    static let appGroup = "H5K2TS4JRX.com.redcoatasher.vidget"
    static let nowPlayingKey = "nowPlaying"
    static let widgetKind = "VidgetNowPlaying"
    static let openURL = URL(string: "vidget://open")!
}

/// What the app publishes for the widget tile to show.
struct NowPlaying: Codable, Equatable {
    var title: String
    var thumbnailURL: String?
    var sourceURL: String
    var isAceStream: Bool

    static func load() -> NowPlaying? {
        guard let data = UserDefaults(suiteName: VidgetShared.appGroup)?.data(forKey: VidgetShared.nowPlayingKey) else { return nil }
        return try? JSONDecoder().decode(NowPlaying.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: VidgetShared.appGroup)?.set(data, forKey: VidgetShared.nowPlayingKey)
    }
}
