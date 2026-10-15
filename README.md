# Vidget

A macOS desktop widget that plays YouTube videos (plus experimental Ace Stream support). Right-click → **Edit Widget…**,
paste a link, hit **Play** — the widget flips back over and starts playing.

## Why it's an app, not (only) a WidgetKit widget

Apple's WidgetKit widgets are static snapshots: no video, no web view, no text input.
Vidget is therefore a tiny accessory app (no Dock icon) whose borderless window is
pinned to the **desktop layer** — the same layer as the built-in desktop widgets — so it
behaves like one: it snaps to the system widget grid, comes in the system widget sizes
(Medium 2×1, Large 2×2, Extra Large 4×2), and "Show Desktop" keeps it visible.

It also ships a real WidgetKit tile ("Vidget" in the widget gallery) showing what's
playing — thumbnail and title. Clicking the tile brings up the player; the tile itself
can't play video, because nothing in WidgetKit can.

## Install

**Download:** grab `Vidget-x.y.z.zip` from the [latest release](https://github.com/redcoatasher/vidget/releases/latest),
unzip, and move `Vidget.app` to `/Applications` (the gallery widget registers from there).
Releases from v0.3.0 are Developer ID signed and notarized; v0.1–0.2 were ad-hoc signed and
need a right-click → **Open** on first launch.

**Build from source** (Xcode 15+, macOS 14+, `brew install xcodegen`):

```sh
./build.sh run     # generates Vidget.xcodeproj, builds build/Vidget.app, launches it
```

`project.yml` is the source of truth for the Xcode project; the `.xcodeproj` is generated
and git-ignored. To work in Xcode, run `xcodegen generate` and open `Vidget.xcodeproj`.
The app group and widget extension sign with the team in `project.yml`; change
`DEVELOPMENT_TEAM` and the group id in the two `.entitlements` files to use your own.

**Cut a release** (maintainer): `./release.sh v0.3.0` — signs with Developer ID,
notarizes, staples, and publishes to GitHub. Needs `xcrun notarytool store-credentials
vidget-notary …` once.

## Using it

| Action | How |
|---|---|
| Set / change the video | Right-click → **Edit Widget…** (also on first launch) |
| Move the widget | Hover the top edge → drag the grip; it snaps to the system widget grid on release |
| Resize | Right-click → **Size** → Medium / Large / Extra Large (the system widget sizes) |
| Gallery tile | Right-click desktop → *Edit Widgets…* → search "Vidget" |
| Play / pause, mute / unmute, restart | Right-click menu, or YouTube's own controls |
| Loop | Checkbox on the settings face |
| Replay something recent | Settings face lists the last 20 links (title + thumbnail); click to play, hover → ✕ to remove |
| Quit | Right-click → **Quit Vidget** |

Accepted links: `youtube.com/watch?v=…`, `youtu.be/…`, `/shorts/…`, `/embed/…`,
`/live/…`, `music.youtube.com/watch?v=…`, a bare 11-char video ID, and `t=` / `start=`
offsets (`90`, `1m30s`, `1h2m`). Playlist and YouTube Music album/playlist links
(`…/playlist?list=…`) play the whole list; **Loop** then loops the list. A link with both
`v=` and `list=` plays that one video. If the clipboard already holds a YouTube link when you open
settings, it's prefilled.

## Ace Stream links (experimental, untested)

Paste `acestream://<40-hex-id>` (or just the id). Ace Stream is peer-to-peer, so the widget
needs a local **Ace Stream engine** to turn the id into video. There's no native macOS engine;
the easy route is Docker:

```sh
docker run -d --name acestream -p 6878:6878 --restart unless-stopped martinbjeldbak/acestream-http-proxy
```

When an Ace link is in the URL field an **Engine** field appears (default `127.0.0.1:6878`).
The widget pings the engine before flipping; if nothing answers you get a message instead of a
black screen. Playback uses the engine's HLS endpoint (`/ace/manifest.m3u8?id=…`) in a native
`<video>` tag. Live streams can take 10–30 s to find peers before the picture appears.

## Behaviour notes

- **Autoplay is muted.** Embedded players can't start with sound without a user
  gesture; click YouTube's speaker icon or use right-click → *Mute / Unmute*.
- Videos whose owners disabled embedding fail with YouTube error 101/150. The widget
  flips back to settings and tells you why.
- The last video, loop setting and window position/size are remembered between launches.
- Snapping reads the frames of the system's desktop widgets to find the grid (180 pt pitch).
  With none on screen it assumes the grid starts 8 pt from the left, under the menu bar.
- The web view can't be 3D-rotated by SwiftUI, so during the flip the player face shows a
  plain black card; the live player reappears once the flip lands.

## Contributing

Issues and PRs welcome. Keep it dependency-free — the whole thing is a handful of Swift
files and a shell script on purpose.

## License

[MIT](LICENSE)

## Layout

```
Sources/Vidget/
  VidgetApp.swift      entry point, accessory activation policy
  WidgetWindow.swift   borderless desktop-level NSWindow; grid snapping + sizes
  WidgetGrid.swift     system widget grid detection, size presets
  WidgetModel.swift    state + persistence
  MediaLink.swift      YouTube-or-AceStream link detection, engine URLs + probe
  YouTubeURL.swift     link → video ID / start time
  WidgetRootView.swift flip container (AnimatableModifier)
  PlayerFace.swift     player side + hover drag grip + empty state
  PlayerView.swift     WKWebView + YouTube IFrame API page
  SettingsFace.swift   URL field, history list, Loop, Cancel / Play
  History.swift        history entries, persistence, oEmbed title lookup
  WidgetMenu.swift     shared right-click menu (AppKit + SwiftUI)
  DragHandle.swift     NSView that drags the window
Sources/Shared/
  VidgetShared.swift   app-group id + NowPlaying record shared with the widget
Sources/VidgetWidget/
  VidgetWidget.swift   WidgetKit "now playing" tile for the gallery
project.yml            xcodegen spec (app + widget extension)
build.sh / release.sh  dev build / signed+notarized release
```
