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
| ⇧⌘A | Annotate the newest screenshot in Preview |
| ⇧⌘D | Show or hide desktop icons |

Every screenshot is copied to the clipboard and shown as a stacked 4:3 thumbnail
in the bottom-left corner. Previews fill their frame, cropping and enlarging as
needed; the original image stays intact. Hover for copy, save to Desktop,
annotate, and X to delete. Only the save button creates a Desktop PNG.
Drag into another app to drop the file; a successful drop removes the preview.
Double-click to annotate in Preview.

Screenshots use temporary storage. Copying or deleting removes the
temporary capture. Dropped files remain available until snip quits so receiving
apps can finish reading them. Annotation uses a separate temporary editing copy.
Screen recordings continue to save to Desktop.

Turn off the system screenshot shortcuts first: System Settings → Keyboard →
Keyboard Shortcuts → Screenshots. snip uses the same keys.

## Installing

Build from source. The build installs to `/Applications/snip.app` and opens it:

```sh
git clone https://github.com/mavdotso/snip.git && cd snip && ./build.sh --install
```

The build signs with the Apple Development certificate in your keychain. You can
also select a certificate with `SIGNING_IDENTITY`. Installation requires a signing
identity so rebuilding preserves the app identity used by Screen Recording
permission. Run the install with access to your login keychain.

Build-only runs can use ad-hoc signing when no certificate is available, but
those builds can require Screen Recording approval again after each change.
macOS asks for permission on the first capture, and may ask once more when
switching from an ad-hoc build to a certificate-signed build.

## Development

```sh
./build.sh            # -> build/snip.app
./tests/run.sh        # native preview and temporary-file checks
swift make-icon.swift # -> AppIcon.icns, after a change to icon.svg
```

The menu bar icon and the app icon come from `icon.svg`
(Nucleo Micro Bold "select-area", licensed for use in this app).
Preview controls use [Hugeicons](https://github.com/hugeicons/hugeicons), bundled
under the [MIT license](assets/hugeicons/LICENSE).

## License

MIT — see [LICENSE](LICENSE).
