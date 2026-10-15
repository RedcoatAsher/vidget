import AppKit
import Combine
import SwiftUI

/// A borderless, transparent window pinned to the desktop layer — the same layer the
/// built-in desktop widgets use — that snaps to their grid and comes in their sizes.
final class WidgetWindow: NSWindow {
    static let frameName = "VidgetWindowFrame"

    private var snapWorkItem: DispatchWorkItem?
    private var isSnapping = false
    private var cancellables = Set<AnyCancellable>()

    init(model: WidgetModel) {
        let size = model.widgetSize.windowSize
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true

        level = WidgetGrid.systemWidgetLevel()
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]

        contentView = NSHostingView(rootView: WidgetRootView(model: model))

        setFrameAutosaveName(Self.frameName)
        if !setFrameUsingName(Self.frameName), let screen = NSScreen.main {
            // First run: top-right of the main screen, which is where the system puts widgets.
            let vf = screen.visibleFrame
            setFrameOrigin(NSPoint(x: vf.maxX - size.width - 24, y: vf.maxY - size.height - 24))
        }
        apply(size: model.widgetSize, animated: false)

        // Snap once the user finishes dragging (didMove fires continuously during a drag).
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: self, queue: .main) {
            [weak self] _ in self?.scheduleSnap()
        }
        model.$widgetSize
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.apply(size: $0, animated: true) }
            .store(in: &cancellables)
    }

    // Borderless windows refuse key status by default; we need it for the URL field.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // MARK: Sizing & snapping

    /// Resizes keeping the top-left corner put, then snaps to the grid.
    private func apply(size: WidgetGrid.Size, animated: Bool) {
        let s = size.windowSize
        var f = frame
        f.origin.y = f.maxY - s.height
        f.size = s
        guard let screen = screen ?? NSScreen.main else { setFrame(f, display: true); return }
        let target = WidgetGrid.snappedFrame(for: f, on: screen)
        setFrame(target, display: true, animate: animated)
    }

    private func scheduleSnap() {
        guard !isSnapping else { return }
        snapWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            // Still dragging? Check again shortly.
            if NSEvent.pressedMouseButtons != 0 { self.scheduleSnap(); return }
            self.snapToGrid()
        }
        snapWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: item)
    }

    private func snapToGrid() {
        guard let screen = screen ?? NSScreen.main else { return }
        let target = WidgetGrid.snappedFrame(for: frame, on: screen)
        guard target != frame else { return }
        isSnapping = true
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().setFrame(target, display: true)
        }, completionHandler: { [weak self] in
            self?.isSnapping = false
        })
    }
}
