# Sky

A better home for your screenshots on macOS.

Keep taking screenshots the way you already do, with ⇧⌘3, ⇧⌘4 or ⇧⌘5. Sky notices each one as soon as macOS saves it and shows your recent screenshots in a small stack at the top of your main display. Point at the stack and it fans out so you can grab, copy, preview or bin any of them.

Sky is a native macOS app written in Swift, SwiftUI and AppKit, and uses Liquid Glass on macOS 26 and later. It lives in the menu bar, has no Dock icon and never takes focus away from the app you're working in.

## What it does

**The shelf**
- A new screenshot drops onto a stack at the top of your main display. The stack hides itself a few seconds later.
- Bring the shelf back at any time the way you'd bring up an auto-hiding Dock: rest the pointer against the middle of the top edge of your main display for a moment. Passing through on the way to a menu, or dragging a window up there, doesn't count.
- Point at the stack to fan it out into a row of your most recent screenshots.
- Point at a screenshot to see how old it is and to copy it, show it in Finder, move it to the Trash or take it off the shelf.
- Drag a screenshot from the shelf straight into Slack, Mail, Finder or anywhere else that accepts files.
- Copying puts both the image and the file on the clipboard, so pasting works in chat apps and in Finder.
- The shelf lets clicks through everywhere except over the screenshots themselves.

**The preview**
- Click a screenshot to open it in a minimal preview window: a fixed 16:9 pane in the middle of the screen that every screenshot fits inside, so stepping between screenshots never resizes it. Small screenshots are shown at their real size rather than enlarged.
- ← and → step through your recent screenshots. ⌘C copies, ⌘⌫ moves to the Trash, ⌘O or a double-click opens the file in its usual app, and Esc or Space closes the preview.
- Clicking anywhere else closes it.

**The menu bar**
- Show or hide the shelf, clear it, or open your screenshots folder.
- *Show Shelf at Top Edge* turns the top-edge reveal on or off.
- *Keep Shelf Visible* stops the shelf hiding itself.
- *Skip macOS Floating Thumbnail* turns off the small preview macOS shows in the corner after a capture. macOS waits for that thumbnail to go away (about five seconds) before it saves the file, so turning it off puts screenshots on the shelf straight away. This changes the same setting as the Options menu in the Screenshot app.
- *Open at Login*.

## How Sky finds your screenshots

Sky watches the folder macOS saves screenshots to: the location chosen in the Screenshot app's Options menu, or your Desktop if you never changed it. If you change the location, Sky follows it within a few seconds.

A file counts as a screenshot when macOS has tagged it as a screen capture (the `kMDItemIsScreenCapture` metadata macOS writes on every capture). Sky doesn't rely on the file name, so it works in any language and with any naming or file format setting, and it ignores other images in the same folder.

Sky reads your screenshots and never uploads them anywhere.

## Requirements

- macOS 14 Sonoma or later
- Xcode 16 or later (Swift 6 toolchain) to build

## Build and run

```sh
git clone https://github.com/sahildmk/sky.git
cd sky
scripts/build-app.sh      # builds build/Sky.app
open build/Sky.app
```

The first time Sky looks at your screenshots folder, macOS asks whether Sky may access it (for example "Sky would like to access files in your Desktop folder"). Allow it, or Sky can't see your screenshots.

The build is universal (Apple silicon and Intel) and signed ad hoc, which is enough to run it on the Mac that built it. To sign with your own Developer ID certificate, which adds a secure timestamp and is what notarisation needs:

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" scripts/build-app.sh
```

To keep Sky around, drag `build/Sky.app` into `/Applications` and turn on *Open at Login* from its menu.

## Development

```sh
swift build                 # build everything
swift test                  # run the unit tests
swift run SkySnapshots out  # render the shelf and preview to PNGs in ./out
```

`SkySnapshots` draws the shelf (collapsed, expanded and hovered) and the preview window to image files, using the newest screenshots in your screenshots folder. Pass a folder first to use other screenshots: `swift run SkySnapshots path/to/screenshots out`.

Liquid Glass only draws in a live window, so each view is shown in a window placed behind the desktop wallpaper and captured from there with ScreenCaptureKit. Nothing appears in front of you, so you can check a visual change while you keep working. The app running it (your terminal, for example) needs the Screen Recording permission.

### Layout

| Target | What it holds |
| --- | --- |
| `SkyCore` | Logic with no UI: recognising screenshot files, resolving the screenshots folder, and the geometry of the shelf and the preview. Covered by `Tests/SkyCoreTests`. |
| `SkyApp` | The menu bar item, the folder watcher, the shelf and preview windows and their SwiftUI views. |
| `Sky` | The app's entry point. |
| `SkySnapshots` | The off-screen renderer described above. |

## Licence

MIT. See [LICENSE](LICENSE).
