import AppKit
import Combine

/// All widget state. Persisted bits live in UserDefaults.
final class WidgetModel: ObservableObject {
    // Persisted
    @Published private(set) var videoID: String?
    @Published private(set) var playlistID: String?
    @Published private(set) var startSeconds: Int = 0
    @Published private(set) var sourceURL: String = ""
    @Published var loop: Bool { didSet { defaults.set(loop, forKey: Keys.loop) } }

    @Published private(set) var history: [HistoryEntry] = HistoryStore.load()

    // Transient UI state
    @Published var isEditing = false
    @Published var draftURL = ""
    @Published var errorMessage: String?
    /// Incremented every time the player should (re)load. Observed by PlayerView.
    @Published private(set) var playRequestID = 0

    /// Set by the app delegate: activates the app and makes the window key.
    var requestKeyboardFocus: (() -> Void)?

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let videoID = "videoID", playlistID = "playlistID", start = "startSeconds", source = "sourceURL", loop = "loop"
    }

    init() {
        videoID = defaults.string(forKey: Keys.videoID)
        playlistID = defaults.string(forKey: Keys.playlistID)
        startSeconds = defaults.integer(forKey: Keys.start)
        sourceURL = defaults.string(forKey: Keys.source) ?? ""
        loop = defaults.bool(forKey: Keys.loop)
    }

    // MARK: Flip to settings

    func beginEditing() {
        draftURL = sourceURL
        errorMessage = nil
        // Convenience: if the clipboard holds a YouTube link and nothing is set yet, prefill it.
        if draftURL.isEmpty,
           let clip = NSPasteboard.general.string(forType: .string),
           YouTubeURL.parse(clip) != nil {
            draftURL = clip.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        isEditing = true
        requestKeyboardFocus?()
    }

    func cancelEditing() {
        errorMessage = nil
        isEditing = false
    }

    // MARK: Submit → flip back and play

    func submit() {
        let raw = draftURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            errorMessage = "Paste a YouTube link first."
            return
        }
        guard let parsed = YouTubeURL.parse(raw) else {
            errorMessage = "That doesn't look like a YouTube video link."
            return
        }
        play(parsed, url: raw)
    }

    /// Plays a history entry: flips back and starts it, bumping it to the top of the list.
    func play(_ entry: HistoryEntry) {
        let parsed = YouTubeURL.Parsed(videoID: entry.videoID, playlistID: entry.playlistID,
                                       startSeconds: entry.startSeconds)
        play(parsed, url: entry.url)
    }

    func removeFromHistory(_ entry: HistoryEntry) {
        history.removeAll { $0.key == entry.key }
        HistoryStore.save(history)
    }

    private func play(_ parsed: YouTubeURL.Parsed, url raw: String) {
        videoID = parsed.videoID
        playlistID = parsed.playlistID
        startSeconds = parsed.startSeconds
        sourceURL = raw
        defaults.set(parsed.videoID, forKey: Keys.videoID)
        defaults.set(parsed.playlistID, forKey: Keys.playlistID)
        defaults.set(parsed.startSeconds, forKey: Keys.start)
        defaults.set(raw, forKey: Keys.source)

        errorMessage = nil
        isEditing = false
        playRequestID += 1
        recordInHistory(parsed, url: raw)
    }

    // MARK: History

    private func recordInHistory(_ parsed: YouTubeURL.Parsed, url: String) {
        var entry = HistoryEntry(parsed: parsed, url: url)
        if let existing = history.first(where: { $0.key == entry.key }) {
            // Keep the title/thumbnail we already looked up; refresh the link and timestamp.
            entry.title = existing.title
            entry.thumbnailURL = existing.thumbnailURL ?? entry.thumbnailURL
        }
        history.removeAll { $0.key == entry.key }
        history.insert(entry, at: 0)
        history = Array(history.prefix(HistoryStore.limit))
        HistoryStore.save(history)

        if entry.title == nil {
            Task { [key = entry.key] in
                let meta = await HistoryStore.fetchMetadata(for: entry)
                await MainActor.run {
                    guard let i = self.history.firstIndex(where: { $0.key == key }) else { return }
                    if let t = meta.title { self.history[i].title = t }
                    if self.history[i].thumbnailURL == nil, let th = meta.thumbnail { self.history[i].thumbnailURL = th }
                    HistoryStore.save(self.history)
                }
            }
        }
    }

    /// Called from the web view when YouTube refuses to play (embedding disabled, removed, etc.).
    func playerFailed(code: Int) {
        let reason: String
        switch code {
        case 2:        reason = "YouTube rejected the video ID."
        case 5:        reason = "The video can't be played in an embedded player."
        case 100:      reason = "That video was removed or is private."
        case 101, 150: reason = "The owner doesn't allow this video to be embedded."
        case 152:      reason = "YouTube rejected the embed origin or this video can't be embedded."
        default:       reason = "YouTube couldn't play this video (error \(code))."
        }
        errorMessage = reason
        draftURL = sourceURL
        isEditing = true
        requestKeyboardFocus?()
    }

    /// True once a video or playlist has been set.
    var hasContent: Bool { videoID != nil || playlistID != nil }

    func quit() { NSApp.terminate(nil) }
}
