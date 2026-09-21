# snip

A small macOS menu bar screenshot tool. One Swift file, no dependencies.

Requires macOS 14 or later.

## Features

| Shortcut | Action |
|---|---|
| ⇧⌘4 | Capture an area or a window |
| ⇧⌘3 | Capture the full screen |
| ⇧⌘6 | Capture the full screen after 5 seconds |
| ⇧⌘5 | Record the screen |
| ⇧⌘2 | Capture text (OCR) to the clipboard |
| ⇧⌘P | Pin a screenshot on top of other windows |
| ⇧⌘A | Annotate the newest screenshot in Preview |
| ⇧⌘D | Show or hide desktop icons |

Every capture saves a PNG to the Desktop, copies the image to the clipboard, and
shows a thumbnail in the bottom-left corner. Thumbnails stack. Hover a thumbnail
for the actions: close, copy, annotate, pin, trash. Drag a thumbnail into another
app to drop the file. Double-click a thumbnail to annotate it.

Turn off the system screenshot shortcuts first: System Settings → Keyboard →
Keyboard Shortcuts → Screenshots. snip uses the same keys.

## Installing

Build from source. The build installs to `/Applications/snip.app` and opens it:

```sh
git clone https://github.com/mavdotso/snip.git && cd snip && ./build.sh --install
```

The build signs with the Apple Development certificate in your keychain, or ad hoc
when there is none. Either way the app runs on the Mac that built it. macOS asks
for the Screen Recording permission on the first capture.

## Development

```sh
./build.sh            # -> build/snip.app
swift make-icon.swift # -> AppIcon.icns, after a change to icon.svg
```

The menu bar icon and the app icon come from `icon.svg`
(Nucleo Micro Bold "select-area", licensed for use in this app).

## License

MIT — see [LICENSE](LICENSE).
