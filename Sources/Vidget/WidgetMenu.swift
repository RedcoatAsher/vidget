import AppKit
import SwiftUI
import WebKit

/// The right-click menu, built once for AppKit (web view / drag grip) and once for SwiftUI (settings face).
enum WidgetMenu {

    // MARK: AppKit

    static func nsMenu(model: WidgetModel, webView: WKWebView?) -> NSMenu {
        let menu = NSMenu()
        let target = MenuTarget.shared
        target.model = model
        target.webView = webView

        func item(_ title: String, _ sel: Selector, key: String = "") -> NSMenuItem {
            let i = NSMenuItem(title: title, action: sel, keyEquivalent: key)
            i.target = target
            return i
        }

        menu.addItem(item("Edit Widget…", #selector(MenuTarget.editWidget), key: "e"))
        if webView != nil {
            menu.addItem(.separator())
            menu.addItem(item("Play / Pause", #selector(MenuTarget.togglePlay), key: " "))
            menu.addItem(item("Mute / Unmute", #selector(MenuTarget.toggleMute), key: "m"))
            menu.addItem(item("Restart Video", #selector(MenuTarget.restart)))
        }
        menu.addItem(.separator())
        menu.addItem(item("Quit Vidget", #selector(MenuTarget.quit), key: "q"))
        return menu
    }

    final class MenuTarget: NSObject {
        static let shared = MenuTarget()
        weak var model: WidgetModel?
        weak var webView: WKWebView?

        @objc func editWidget() { model?.beginEditing() }
        @objc func togglePlay() { webView?.evaluateJavaScript("vidget.togglePlay()") }
        @objc func toggleMute() { webView?.evaluateJavaScript("vidget.toggleMute()") }
        @objc func restart()    { webView?.evaluateJavaScript("vidget.restart()") }
        @objc func quit()       { model?.quit() }
    }

    // MARK: SwiftUI

    @ViewBuilder
    static func swiftUIItems(model: WidgetModel) -> some View {
        Button("Edit Widget…") { model.beginEditing() }
        Divider()
        Button("Quit Vidget") { model.quit() }
    }
}
