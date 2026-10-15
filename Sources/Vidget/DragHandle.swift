import AppKit
import SwiftUI

/// Transparent AppKit strip that moves the window when dragged and
/// shows the widget menu on right-click.
struct DragHandle: NSViewRepresentable {
    let model: WidgetModel

    func makeNSView(context: Context) -> DragHandleView {
        let v = DragHandleView()
        v.model = model
        return v
    }
    func updateNSView(_ nsView: DragHandleView, context: Context) {}
}

final class DragHandleView: NSView {
    weak var model: WidgetModel?

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let model else { return nil }
        return WidgetMenu.nsMenu(model: model, webView: nil)
    }

    override var mouseDownCanMoveWindow: Bool { true }
}
