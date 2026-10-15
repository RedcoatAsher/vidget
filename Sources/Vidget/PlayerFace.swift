import SwiftUI

/// Front of the widget: the YouTube player, a hover-revealed drag grip, and an empty state.
struct PlayerFace: View {
    @ObservedObject var model: WidgetModel
    /// True while flipping — the web view (an AppKit view) can't be 3D-rotated, so we hide it.
    let hidePlayer: Bool
    @State private var hovering = false

    var body: some View {
        ZStack {
            Color.black

            if !model.hasContent {
                EmptyState()
            } else {
                PlayerView(model: model)
                    .opacity(hidePlayer ? 0 : 1)
                    .allowsHitTesting(!hidePlayer)
                PlaceholderGlyph().opacity(hidePlayer ? 1 : 0)
            }

            // Drag grip along the top edge (WKWebView swallows mouse-down, so the
            // window can't be moved by dragging the video itself).
            VStack(spacing: 0) {
                DragHandle(model: model)
                    .frame(height: 26)
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: 44, height: 5)
                            .padding(.top, 7)
                            .allowsHitTesting(false)
                    }
                    .background(
                        LinearGradient(colors: [.black.opacity(0.65), .clear],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .opacity(hovering ? 1 : 0)
                    .animation(.easeOut(duration: 0.18), value: hovering)
                Spacer(minLength: 0)
            }
        }
        .onHover { hovering = $0 }
        .contextMenu { WidgetMenu.swiftUIItems(model: model) }
    }
}

private struct EmptyState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 34, weight: .light))
            Text("Right-click → Edit Widget")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.7))
    }
}

private struct PlaceholderGlyph: View {
    var body: some View {
        Image(systemName: "play.fill")
            .font(.system(size: 40))
            .foregroundStyle(.white.opacity(0.25))
    }
}
