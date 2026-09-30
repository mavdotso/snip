let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let snip = Snip()
let clipboardItems: [NSPasteboardItem] = NSPasteboard.general.pasteboardItems?.map { item in
    let copy = NSPasteboardItem()
    for type in item.types {
        if let data = item.data(forType: type) { copy.setData(data, forType: type) }
    }
    return copy
} ?? []
try FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
defer {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.writeObjects(clipboardItems)
    try? FileManager.default.removeItem(at: captureDir)
    try? FileManager.default.removeItem(at: saveDir)
}

func fixture(_ size: NSSize) throws -> (Preview, Data) {
    let image = NSImage(size: size, flipped: false) { rect in
        NSColor.systemOrange.setFill()
        rect.fill()
        return true
    }
    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    let data = bitmap.representation(using: .png, properties: [:])!
    let file = try temporaryCapturePath()
    try data.write(to: URL(fileURLWithPath: file))
    return (Preview(file: file, image: NSImage(contentsOfFile: file)!), data)
}

for size in [NSSize(width: 800, height: 100), NSSize(width: 100, height: 800), NSSize(width: 8, height: 6)] {
    let (preview, _) = try fixture(size)
    assert(preview.frame.size == NSSize(width: 240, height: 180))
    let view = preview.contentView!
    let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
    view.cacheDisplay(in: view.bounds, to: bitmap)
    // All four interior corners must contain image pixels, even for tiny captures.
    for x in [20, bitmap.pixelsWide - 21] {
        for y in [20, bitmap.pixelsHigh - 21] {
            let color = bitmap.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
            assert(color.redComponent > 0.8 && color.alphaComponent > 0.95, "Preview must fill its frame")
        }
    }
    if size.width == 8, let output = ProcessInfo.processInfo.environment["SNIP_TEST_RENDER"] {
        preview.row.alphaValue = 1
        view.layoutSubtreeIfNeeded()
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
    }
    let deleteButton = preview.row.arrangedSubviews.compactMap { $0 as? NSButton }.first { $0.toolTip == "Delete screenshot" }!
    preview.row.alphaValue = 1
    deleteButton.performClick(nil)
    assert(!FileManager.default.fileExists(atPath: preview.file))
}

let (copied, _) = try fixture(NSSize(width: 32, height: 24))
copied.copyImage()
assert(!FileManager.default.fileExists(atPath: copied.file))
assert(NSPasteboard.general.canReadObject(forClasses: [NSImage.self], options: nil))
let unsavedFiles = try FileManager.default.contentsOfDirectory(atPath: saveDir.path)
assert(unsavedFiles.isEmpty)

let (saved, original) = try fixture(NSSize(width: 48, height: 12))
saved.save()
let savedFiles = try FileManager.default.contentsOfDirectory(at: saveDir, includingPropertiesForKeys: nil)
assert(savedFiles.count == 1)
let savedBytes = try Data(contentsOf: savedFiles[0])
assert(savedBytes == original, "Save must preserve full original PNG")
assert(!FileManager.default.fileExists(atPath: saved.file))

let (dropped, _) = try fixture(NSSize(width: 24, height: 24))
dropped.retainTemporaryFile = true
dropped.dismiss()
assert(FileManager.default.fileExists(atPath: dropped.file))
snip.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
assert(!FileManager.default.fileExists(atPath: dropped.file))
assert(FileManager.default.fileExists(atPath: savedFiles[0].path))
print("Passed: 4:3 aspect fill, tiny-image enlargement, discard/copy cleanup, original PNG save, deferred drag cleanup.")
