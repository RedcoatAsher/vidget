# Vidget

A macOS desktop widget that plays YouTube videos. Right-click → **Edit Widget…**,
paste a link, hit **Play** — the widget flips back over and starts playing.

## Why it's an app, not a WidgetKit widget

Apple's WidgetKit widgets are static snapshots: no video, no web view, no text input.
Vidget is therefore a tiny accessory app (no Dock icon) whose borderless window is
pinned to the **desktop layer** — just above the desktop icons, below every normal
window — so it behaves like the built-in desktop widgets. "Show Desktop" keeps it visible.

## Install

**Download:** grab `Vidget.zip` from the [latest release](https://github.com/redcoatasher/vidget/releases/latest),
unzip, and move `Vidget.app` wherever you like. The build is ad-hoc signed (not notarized),
so the first launch needs a right-click → **Open**, or:

```sh
xattr -dr com.apple.quarantine Vidget.app
```

**Build from source:**

```sh
./build.sh run     # compiles Sources/Vidget → build/Vidget.app and launches it
```

Requires Xcode command-line tools (`xcrun swiftc`). Targets macOS 13+.
`Package.swift` is only there so Xcode / VS Code give you code completion — open the
folder and edit, then use `build.sh` to produce the bundle.

## Using it

| Action | How |
|---|---|
| Set / change the video | Right-click → **Edit Widget…** (also on first launch) |
| Move the widget | Hover the top edge → drag the grip |
| Resize | Drag any edge/corner (locked to 16:9) |
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

## Behaviour notes

- **Autoplay is muted.** Embedded players can't start with sound without a user
  gesture; click YouTube's speaker icon or use right-click → *Mute / Unmute*.
- Videos whose owners disabled embedding fail with YouTube error 101/150. The widget
  flips back to settings and tells you why.
- The last video, loop setting and window position/size are remembered between launches.
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
  WidgetWindow.swift   borderless desktop-level NSWindow
  WidgetModel.swift    state + persistence
  YouTubeURL.swift     link → video ID / start time
  WidgetRootView.swift flip container (AnimatableModifier)
  PlayerFace.swift     player side + hover drag grip + empty state
  PlayerView.swift     WKWebView + YouTube IFrame API page
  SettingsFace.swift   URL field, history list, Loop, Cancel / Play
  History.swift        history entries, persistence, oEmbed title lookup
  WidgetMenu.swift     shared right-click menu (AppKit + SwiftUI)
  DragHandle.swift     NSView that drags the window
```
