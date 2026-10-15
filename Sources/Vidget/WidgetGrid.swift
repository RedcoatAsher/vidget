import AppKit

/// Mirrors the layout the system uses for desktop widgets so Vidget lines up with them.
///
/// Measured on macOS: desktop widgets live on a 180-pt grid; each widget's window frame is
/// its grid cell (180×180, 360×180, 360×360 …) and the visible widget is inset inside that.
/// Notification Center owns those windows, so we can read their frames and infer the grid.
enum WidgetGrid {
    static let pitch: CGFloat = 180
    /// Visible widget inset from its grid cell edge (16 pt between neighbouring widgets).
    static let inset: CGFloat = 8

    enum Size: String, CaseIterable, Codable {
        case medium, large, extraLarge

        var cells: (w: Int, h: Int) {
            switch self {
            case .medium:     return (2, 1)
            case .large:      return (2, 2)
            case .extraLarge: return (4, 2)
            }
        }
        var title: String {
            switch self {
            case .medium:     return "Medium"
            case .large:      return "Large"
            case .extraLarge: return "Extra Large"
            }
        }
        /// Visible window size (cell size minus the inset on each side).
        var windowSize: NSSize {
            NSSize(width: CGFloat(cells.w) * pitch - 2 * inset,
                   height: CGFloat(cells.h) * pitch - 2 * inset)
        }
    }

    /// Frames of the system's desktop widgets, in AppKit (bottom-left origin) coordinates.
    static func systemWidgetFrames() -> [NSRect] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]],
              let primaryHeight = NSScreen.screens.first?.frame.height else { return [] }
        return list.compactMap { w in
            guard (w[kCGWindowOwnerName as String] as? String) == "Notification Center",
                  let layer = w[kCGWindowLayer as String] as? Int, layer < 0,      // desktop level, not banners
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = b["X"], let y = b["Y"], let width = b["Width"], let height = b["Height"],
                  (100...1000).contains(width), (100...1000).contains(height) else { return nil }
            return NSRect(x: x, y: primaryHeight - y - height, width: width, height: height)
        }
    }

    /// The window level the system draws desktop widgets at (so we sit alongside, not under, them).
    static func systemWidgetLevel() -> NSWindow.Level {
        let fallback = Int(CGWindowLevelForKey(.desktopIconWindow)) + 2
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return NSWindow.Level(rawValue: fallback)
        }
        let layers = list.compactMap { w -> Int? in
            guard (w[kCGWindowOwnerName as String] as? String) == "Notification Center",
                  let layer = w[kCGWindowLayer as String] as? Int, layer < 0 else { return nil }
            return layer
        }
        return NSWindow.Level(rawValue: layers.max() ?? fallback)
    }

    /// Top-left corner of the grid on `screen`, in AppKit coordinates (x = left edge, top = y of the top).
    static func gridOrigin(on screen: NSScreen) -> (left: CGFloat, top: CGFloat) {
        let sf = screen.frame
        if let w = systemWidgetFrames().first(where: { sf.intersects($0) }) {
            let dx = (w.minX - sf.minX).truncatingRemainder(dividingBy: pitch)
            let dy = (sf.maxY - w.maxY).truncatingRemainder(dividingBy: pitch)
            return (sf.minX + dx, sf.maxY - dy)
        }
        // No system widgets to align with: 8 pt from the left, right under the menu bar.
        let menuBar = sf.maxY - screen.visibleFrame.maxY
        return (sf.minX + 8, sf.maxY - menuBar)
    }

    /// Nearest grid-aligned frame for a window of `frame`'s size, kept on screen.
    static func snappedFrame(for frame: NSRect, on screen: NSScreen) -> NSRect {
        let o = gridOrigin(on: screen)
        let vf = screen.visibleFrame
        var col = ((frame.minX - inset - o.left) / pitch).rounded()
        var row = ((o.top - inset - frame.maxY) / pitch).rounded()

        let maxCol = ((vf.maxX - inset - frame.width - o.left) / pitch).rounded(.down)
        let maxRow = ((o.top - inset - frame.height - vf.minY) / pitch).rounded(.down)
        col = min(max(col, 0), max(maxCol, 0))
        row = min(max(row, 0), max(maxRow, 0))

        let x = o.left + col * pitch + inset
        let top = o.top - row * pitch - inset
        return NSRect(x: x, y: top - frame.height, width: frame.width, height: frame.height)
    }
}
