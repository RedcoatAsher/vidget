import SwiftUI
import WebKit

/// WKWebView hosting the YouTube IFrame Player. Reloads whenever `model.playRequestID` changes.
struct PlayerView: NSViewRepresentable {
    @ObservedObject var model: WidgetModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeNSView(context: Context) -> WidgetWebView {
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []      // allow (muted) autoplay
        config.userContentController.add(context.coordinator, name: "vidget")
        if #available(macOS 12.3, *) {
            config.preferences.isElementFullscreenEnabled = true
        }

        let webView = WidgetWebView(frame: .zero, configuration: config)
        webView.model = model
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")       // no white flash on load
        webView.wantsLayer = true
        webView.layer?.cornerRadius = WidgetRootView.cornerRadius
        webView.layer?.masksToBounds = true

        context.coordinator.webView = webView
        context.coordinator.loadIfNeeded()
        return webView
    }

    func updateNSView(_ webView: WidgetWebView, context: Context) {
        context.coordinator.loadIfNeeded()
    }

    static func dismantleNSView(_ webView: WidgetWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "vidget")
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let model: WidgetModel
        weak var webView: WKWebView?
        private var loadedRequestID = -1

        init(model: WidgetModel) { self.model = model }

        func loadIfNeeded() {
            guard let webView, model.hasContent,
                  loadedRequestID != model.playRequestID else { return }
            loadedRequestID = model.playRequestID
            let html = PlayerHTML.render(videoID: model.videoID, playlistID: model.playlistID,
                                         start: model.startSeconds, loop: model.loop)
            // The page needs a real https origin so the IFrame API's origin/referrer checks pass.
            // It must NOT be youtube.com itself — YouTube refuses to embed from its own origin
            // (player error 152).
            webView.loadHTMLString(html, baseURL: URL(string: "https://vidget.local/player"))
        }

        func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }
            if type == "error", let code = body["code"] as? Int {
                DispatchQueue.main.async { self.model.playerFailed(code: code) }
            }
        }

        // Keep every navigation inside the player; open real links in the browser.
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if action.navigationType == .linkActivated, let url = action.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

/// WKWebView whose right-click menu is the widget menu instead of WebKit's.
final class WidgetWebView: WKWebView {
    weak var model: WidgetModel?

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        menu.removeAllItems()
        guard let model else { return }
        for item in WidgetMenu.nsMenu(model: model, webView: self).items {
            menu.addItem(item.copy() as! NSMenuItem)
        }
    }
}

// MARK: - Page

enum PlayerHTML {
    static func render(videoID: String?, playlistID: String?, start: Int, loop: Bool) -> String {
        // A playlist (incl. YouTube Music albums/playlists) plays through the IFrame API's
        // listType; loop then loops the whole list. A lone video loops via playlist=<its id>.
        // When a link carries both v= and list=, the specific video wins (the API would
        // otherwise ignore videoId and start the list from the top).
        var vars: [String] = []
        if let list = playlistID, videoID == nil {
            vars.append("listType: 'playlist', list: '\(list)'")
            if loop { vars.append("loop: 1") }
        } else if let id = videoID, loop {
            vars.append("loop: 1, playlist: '\(id)'")
        }
        let videoLine = videoID.map { "videoId: '\($0)'," } ?? ""
        let extraVars = vars.isEmpty ? "" : vars.joined(separator: ", ") + ","
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
          html, body { margin: 0; height: 100%; background: #000; overflow: hidden; }
          #player { position: absolute; inset: 0; width: 100%; height: 100%; }
        </style>
        </head>
        <body>
        <div id="player"></div>
        <script>
          var player = null;
          var vidget = {
            togglePlay: function () {
              if (!player) return;
              player.getPlayerState() === YT.PlayerState.PLAYING ? player.pauseVideo() : player.playVideo();
            },
            toggleMute: function () {
              if (!player) return;
              player.isMuted() ? player.unMute() : player.mute();
            },
            restart: function () { if (player) { player.seekTo(0, true); player.playVideo(); } }
          };
          function onYouTubeIframeAPIReady() {
            player = new YT.Player('player', {
              \(videoLine)
              playerVars: {
                autoplay: 1, mute: 1, playsinline: 1, start: \(start),
                rel: 0, modestbranding: 1, iv_load_policy: 3, \(extraVars)
              },
              events: {
                onReady: function (e) { e.target.mute(); e.target.playVideo(); },
                onError: function (e) {
                  window.webkit.messageHandlers.vidget.postMessage({ type: 'error', code: e.data });
                }
              }
            });
          }
          var tag = document.createElement('script');
          tag.src = 'https://www.youtube.com/iframe_api';
          document.head.appendChild(tag);
        </script>
        </body>
        </html>
        """
    }
}
