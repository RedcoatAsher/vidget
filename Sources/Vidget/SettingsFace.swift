import SwiftUI

/// Back of the widget: paste a link, choose options, hit Play.
struct SettingsFace: View {
    @ObservedObject var model: WidgetModel
    @FocusState private var urlFocused: Bool

    var body: some View {
        ZStack {
            Rectangle().fill(.regularMaterial)
            Color.black.opacity(0.35)

            VStack(alignment: .leading, spacing: 8) {
                if model.widgetSize != .medium {
                    HStack(spacing: 6) {
                        Image(systemName: "play.rectangle.fill")
                        Text("Vidget").fontWeight(.semibold)
                        Spacer()
                        Text("YouTube widget")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 13))
                }

                TextField("Paste a YouTube or acestream:// link…", text: $model.draftURL)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .focused($urlFocused)
                    .onSubmit { model.submit() }

                if model.showsEngineField {
                    HStack(spacing: 6) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundStyle(.secondary)
                        Text("Engine").font(.system(size: 12))
                        TextField("127.0.0.1:6878", text: $model.engineAddress)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                            .onSubmit { model.submit() }
                    }
                    .help("Address of your local Ace Stream engine")
                }

                if let error = model.errorMessage {
                    Label(error, systemImage: error.hasSuffix("…") ? "hourglass" : "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(error.hasSuffix("…") ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange))
                        .lineLimit(2)
                }

                HistoryList(model: model)

                HStack {
                    Toggle("Loop", isOn: $model.loop)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 12))
                    Spacer()
                    if model.hasContent {
                        Button("Cancel") { model.cancelEditing() }
                            .keyboardShortcut(.cancelAction)
                    }
                    Button {
                        model.submit()
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(model.widgetSize == .medium ? 10 : 14)
        }
        .foregroundStyle(.primary)
        .onChange(of: model.isEditing) { editing in
            if editing { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { urlFocused = true } }
        }
        .onAppear { if model.isEditing { urlFocused = true } }
        .contextMenu { WidgetMenu.swiftUIItems(model: model) }
    }
}

// MARK: - History

private struct HistoryList: View {
    @ObservedObject var model: WidgetModel

    var body: some View {
        Group {
            if model.history.isEmpty {
                Text("Videos you play will appear here.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: true) {
                    LazyVStack(spacing: 2) {
                        ForEach(model.history) { entry in
                            HistoryRow(entry: entry, isCurrent: entry.url == model.sourceURL,
                                       play: { model.play(entry) },
                                       remove: { model.removeFromHistory(entry) })
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry
    let isCurrent: Bool
    let play: () -> Void
    let remove: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Thumbnail(urlString: entry.thumbnailURL,
                      placeholderSymbol: entry.isAceStream ? "antenna.radiowaves.left.and.right"
                                       : entry.videoID == nil ? "music.note.list" : "play.rectangle")
                .frame(width: 48, height: 27)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            Text(entry.displayTitle)
                .font(.system(size: 12, weight: isCurrent ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isCurrent && !hovering {
                Image(systemName: "waveform")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Button(action: remove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .help("Remove from history")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(hovering ? 0.12 : 0))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: play)
        .onHover { hovering = $0 }
        .help(entry.url)
    }
}

private struct Thumbnail: View {
    let urlString: String?
    let placeholderSymbol: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
            if let s = urlString, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        Image(systemName: placeholderSymbol)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
    }
}
