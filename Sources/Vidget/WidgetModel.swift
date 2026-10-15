import AppKit
import Combine
import WidgetKit

/// All widget state. Persisted bits live in UserDefaults.
final class WidgetModel: ObservableObject {
    // Persisted
    @Published private(set) var videoID: String?
    @Published private(set) var playlistID: String?
    @Published private(set) var aceStreamID: String?
    /// host:port of the local Ace Stream engine.
    @Published var engineAddress: String { didSet { defaults.set(engineAddress, forKey: Keys.engine) } }
    @Published private(set) var startSeconds: Int = 0
    @Published private(set) var sourceURL: String = ""
    @Published var loop: Bool { didSet { defaults.set(loop, forKey: Keys.loop) } }
    /// A system widget size preset, or nil once the user has resized freely.
    @Published var widgetSize: WidgetGrid.Size? { didSet { defaults.set(widgetSize?.rawValue, forKey: Keys.size) } }

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
        static let videoID = "videoID", playlistID = "playlistID", ace = "aceStreamID", engine = "engineAddress", size = "widgetSize", start = "startSeconds", source = "sourceURL", loop = "loop"
    }

    init() {
        videoID = defaults.string(forKey: Keys.videoID)
        playlistID = defaults.string(forKey: Keys.playlistID)
        aceStreamID = defaults.string(forKey: Keys.ace)
        engineAddress = defaults.string(forKey: Keys.engine) ?? AceStream.defaultEngine
        startSeconds = defaults.integer(forKey: Keys.start)
        sourceURL = defaults.string(forKey: Keys.source) ?? ""
        loop = defaults.bool(forKey: Keys.loop)
        // First launch defaults to Extra Large; afterwards nil means "custom size, keep the saved frame".
        if defaults.object(forKey: Keys.size) == nil && defaults.string(forKey: Keys.videoID) == nil {
            widgetSize = .extraLarge
        } else {
            widgetSize = defaults.string(forKey: Keys.size).flatMap(WidgetGrid.Size.init)
        }
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
        guard let link = MediaLink.parse(raw) else {
            errorMessage = "That doesn't look like a YouTube or acestream:// link."
            return
        }
        play(link, url: raw)
    }

    /// Plays a history entry: flips back and starts it, bumping it to the top of the list.
    func play(_ entry: HistoryEntry) {
        play(entry.link, url: entry.url)
    }

    /// True while the pasted link (or the playing one) is an Ace Stream — reveals the engine field.
    var showsEngineField: Bool {
        AceStream.looksLikeAceLink(draftURL) || aceStreamID != nil
    }

    private func play(_ link: MediaLink, url raw: String) {
        switch link {
        case .youtube(let parsed):
            apply(parsed, url: raw)
            startPlayback(link, url: raw)
        case .acestream(let id):
            // Don't flip to a black screen if there's no engine to talk to.
            errorMessage = "Checking Ace Stream engine…"
            let engine = engineAddress
            Task {
                let ok = await AceStream.engineIsReachable(engine)
                await MainActor.run {
                    guard ok else {
                        self.errorMessage = "No Ace Stream engine at \(engine). Start one (see README) or fix the address."
                        return
                    }
                    self.applyAce(id, url: raw)
                    self.startPlayback(link, url: raw)
                }
            }
        }
    }

    private func applyAce(_ id: String, url raw: String) {
        videoID = nil; playlistID = nil; startSeconds = 0
        aceStreamID = id
        sourceURL = raw
        defaults.removeObject(forKey: Keys.videoID)
        defaults.removeObject(forKey: Keys.playlistID)
        defaults.set(0, forKey: Keys.start)
        defaults.set(id, forKey: Keys.ace)
        defaults.set(raw, forKey: Keys.source)
    }

    private func startPlayback(_ link: MediaLink, url raw: String) {
        errorMessage = nil
        isEditing = false
        playRequestID += 1
        recordInHistory(link, url: raw)
        publishToWidget()
    }

    /// Hands the current item to the WidgetKit tile (title, thumbnail) and asks it to refresh.
    private func publishToWidget() {
        guard let entry = history.first else { return }
        NowPlaying(title: entry.displayTitle, thumbnailURL: entry.thumbnailURL,
                   sourceURL: entry.url, isAceStream: entry.isAceStream).save()
        WidgetCenter.shared.reloadTimelines(ofKind: VidgetShared.widgetKind)
    }

    func removeFromHistory(_ entry: HistoryEntry) {
        history.removeAll { $0.key == entry.key }
        HistoryStore.save(history)
    }

    private func apply(_ parsed: YouTubeURL.Parsed, url raw: String) {
        aceStreamID = nil
        videoID = parsed.videoID
        playlistID = parsed.playlistID
        startSeconds = parsed.startSeconds
        sourceURL = raw
        defaults.removeObject(forKey: Keys.ace)
        defaults.set(parsed.videoID, forKey: Keys.videoID)
        defaults.set(parsed.playlistID, forKey: Keys.playlistID)
        defaults.set(parsed.startSeconds, forKey: Keys.start)
        defaults.set(raw, forKey: Keys.source)
    }

    // MARK: History

    private func recordInHistory(_ link: MediaLink, url: String) {
        var entry = HistoryEntry(link: link, url: url)
        if let existing = history.first(where: { $0.key == entry.key }) {
            // Keep the title/thumbnail we already looked up; refresh the link and timestamp.
            entry.title = existing.title
            entry.thumbnailURL = existing.thumbnailURL ?? entry.thumbnailURL
        }
        history.removeAll { $0.key == entry.key }
        history.insert(entry, at: 0)
        history = Array(history.prefix(HistoryStore.limit))
        HistoryStore.save(history)

        if entry.title == nil, !entry.isAceStream {
            Task { [key = entry.key] in
                let meta = await HistoryStore.fetchMetadata(for: entry)
                await MainActor.run {
                    guard let i = self.history.firstIndex(where: { $0.key == key }) else { return }
                    if let t = meta.title { self.history[i].title = t }
                    if self.history[i].thumbnailURL == nil, let th = meta.thumbnail { self.history[i].thumbnailURL = th }
                    HistoryStore.save(self.history)
                    if i == 0 { self.publishToWidget() }
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
    var hasContent: Bool { videoID != nil || playlistID != nil || aceStreamID != nil }

    /// Called from the web view when the Ace Stream <video> element errors out.
    func aceStreamFailed() {
        errorMessage = "The engine accepted the ID but no stream arrived — it may be offline or still finding peers. Try again."
        draftURL = sourceURL
        isEditing = true
        requestKeyboardFocus?()
    }

    func quit() { NSApp.terminate(nil) }
}
