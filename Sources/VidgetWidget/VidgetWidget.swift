import SwiftUI
import WidgetKit

/// A static "now playing" tile for the system widget gallery. WidgetKit can't play video,
/// so this shows the current item's thumbnail and title; clicking it brings up Vidget.
@main
struct VidgetWidgetBundle: WidgetBundle {
    var body: some Widget { VidgetWidget() }
}

struct VidgetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: VidgetShared.widgetKind, provider: Provider()) { entry in
            VidgetWidgetView(entry: entry)
                .widgetURL(VidgetShared.openURL)
        }
        .configurationDisplayName("Vidget")
        .description("What's playing in your Vidget desktop player. Click to open it.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Timeline

struct Entry: TimelineEntry {
    let date: Date
    let nowPlaying: NowPlaying?
    let thumbnail: NSImage?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, nowPlaying: NowPlaying(title: "Video title", thumbnailURL: nil, sourceURL: "", isAceStream: false), thumbnail: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        Task { completion(await makeEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task {
            // The app reloads us whenever playback changes; nothing to poll.
            completion(Timeline(entries: [await makeEntry()], policy: .never))
        }
    }

    private func makeEntry() async -> Entry {
        let np = NowPlaying.load()
        var image: NSImage?
        if let s = np?.thumbnailURL, let url = URL(string: s),
           let (data, _) = try? await URLSession.shared.data(from: url) {
            image = NSImage(data: data)
        }
        return Entry(date: .now, nowPlaying: np, thumbnail: image)
    }
}

// MARK: - View

struct VidgetWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: Entry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let img = entry.thumbnail {
                GeometryReader { geo in
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
            } else {
                emptyBackground
            }

            VStack(alignment: .leading, spacing: 4) {
                Spacer(minLength: 0)
                if let np = entry.nowPlaying {
                    HStack(spacing: 5) {
                        Image(systemName: np.isAceStream ? "antenna.radiowaves.left.and.right" : "play.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("PLAYING IN VIDGET")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.6)
                    }
                    .foregroundStyle(.white.opacity(0.75))
                    Text(np.title)
                        .font(.system(size: family == .systemSmall ? 13 : 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(family == .systemSmall ? 3 : 2)
                } else {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("Open Vidget")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Paste a YouTube link to start.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(14)
        }
        .containerBackground(for: .widget) { Color.black }
    }

    private var emptyBackground: some View {
        LinearGradient(colors: [Color(red: 0.16, green: 0.16, blue: 0.2), .black],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
