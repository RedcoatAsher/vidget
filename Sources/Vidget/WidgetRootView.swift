import SwiftUI

/// Top-level view: a rounded card that flips between the player (front) and settings (back).
struct WidgetRootView: View {
    @ObservedObject var model: WidgetModel
    @State private var angle: Double = 0          // 0 = player, 180 = settings
    @State private var isFlipping = false

    static let cornerRadius: CGFloat = 18
    static let flipDuration: Double = 0.55

    var body: some View {
        ZStack {
            PlayerFace(model: model, hidePlayer: isFlipping || model.isEditing)
                .modifier(FlipFace(angle: angle, isBack: false))
            SettingsFace(model: model)
                .modifier(FlipFace(angle: angle, isBack: true))
        }
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .onAppear { angle = model.isEditing ? 180 : 0 }
        .onChange(of: model.isEditing) { _, editing in
            isFlipping = true
            withAnimation(.easeInOut(duration: Self.flipDuration)) {
                angle = editing ? 180 : 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.flipDuration + 0.05) {
                isFlipping = false
            }
        }
    }
}

/// Rotates a face around the Y axis and hides it while it's facing away.
/// Being an AnimatableModifier means the visibility threshold tracks the *animated* angle.
struct FlipFace: AnimatableModifier {
    var angle: Double
    let isBack: Bool

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        let facingUser = isBack ? angle >= 90 : angle < 90
        content
            .rotation3DEffect(.degrees(isBack ? angle - 180 : angle),
                              axis: (x: 0, y: 1, z: 0),
                              perspective: 0.55)
            .opacity(facingUser ? 1 : 0)
            .allowsHitTesting(facingUser)
    }
}
