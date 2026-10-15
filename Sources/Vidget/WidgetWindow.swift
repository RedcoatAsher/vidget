import AppKit
import SwiftUI

/// A borderless, transparent window pinned to the desktop layer — it sits just
/// above the desktop icons and below every normal app window, like the
/// built-in macOS desktop widgets. "Show Desktop" keeps it visible.
final class WidgetWindow: NSWindow {
    static let frameName = "VidgetWindowFrame"

    init(model: WidgetModel) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 248),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        titlebarAppearsTransparent = true

        // Desktop layer: one step above Finder's desktop icons.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]

        minSize = NSSize(width: 320, height: 180)
        contentAspectRatio = NSSize(width: 16, height: 9)

        let root = WidgetRootView(model: model)
        contentView = NSHostingView(rootView: root)

        setFrameAutosaveName(Self.frameName)
        if !setFrameUsingName(Self.frameName) {
            // First run: bottom-right corner of the main screen.
            if let screen = NSScreen.main {
                let v = screen.visibleFrame
                setFrameOrigin(NSPoint(x: v.maxX - frame.width - 24, y: v.minY + 24))
            }
        }
    }

    // Borderless windows refuse key status by default; we need it for the URL field.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
