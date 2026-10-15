import AppKit
import SwiftUI

@main
enum VidgetMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)   // no Dock icon, no menu bar — it's a widget
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: WidgetWindow!
    private let model = WidgetModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = WidgetWindow(model: model)
        model.requestKeyboardFocus = { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            self?.window.makeKeyAndOrderFront(nil)
        }
        window.orderFront(nil)

        // Nothing saved yet → start on the settings face so the user can paste a link.
        if !model.hasContent {
            model.beginEditing()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
