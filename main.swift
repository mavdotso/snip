import Cocoa
import Carbon
import Vision

let saveDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
let captureDir = FileManager.default.temporaryDirectory.appendingPathComponent("snip-\(UUID().uuidString)", isDirectory: true)

func temporaryCapturePath() throws -> String {
    try FileManager.default.createDirectory(at: captureDir, withIntermediateDirectories: true)
    return captureDir.appendingPathComponent("Screenshot-\(UUID().uuidString).png").path
}

func newPath(_ ext: String) -> String {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss.SSS"
    let name = "Screenshot \(f.string(from: Date()))"
    var url = saveDir.appendingPathComponent("\(name).\(ext)")
    var suffix = 2
    while FileManager.default.fileExists(atPath: url.path) {
        url = saveDir.appendingPathComponent("\(name) (\(suffix)).\(ext)")
        suffix += 1
    }
    return url.path
}

func screencapture(_ args: [String], then: @escaping (Bool) -> Void = { _ in }) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    p.arguments = args
    p.terminationHandler = { p in
        let succeeded = p.terminationStatus == 0
        DispatchQueue.main.async { then(succeeded) }
    }
    do { try p.run() } catch { then(false) }
}

func copyToClipboard(_ items: [NSPasteboardWriting]) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.writeObjects(items)
}

final class DragView: NSImageView, NSDraggingSource {
    var fileURL: URL!
    // Crop only the thumbnail; all actions use the original full-resolution image.
    override func draw(_ dirtyRect: NSRect) {
        guard let image, image.size.width > 0, image.size.height > 0 else { return }
        let scale = max(bounds.width / image.size.width, bounds.height / image.size.height)
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let destination = NSRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: bounds).addClip()
        image.draw(in: destination, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
    }
    override func mouseDragged(with e: NSEvent) {
        let item = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
        item.setDraggingFrame(bounds, contents: image)
        beginDraggingSession(with: [item], event: e, source: self)
    }
    override func mouseUp(with e: NSEvent) { if e.clickCount == 2 { (window as? Preview)?.annotate() } }
    func draggingSession(_ s: NSDraggingSession, sourceOperationMaskFor c: NSDraggingContext) -> NSDragOperation { .copy }
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        guard !operation.isEmpty, let preview = window as? Preview else { return }
        // Receivers can read a dropped file after the session ends. Keep its temporary
        // source until app termination, without creating an automatic Desktop copy.
        preview.retainTemporaryFile = true
        preview.dismiss()
    }
}

final class Preview: NSPanel {
    static var all: [Preview] = []
    let file: String
    let img: NSImage
    let row: NSStackView
    var retainTemporaryFile = false
    private var isDismissing = false

    static func layout() {
        let screen = NSScreen.main!.visibleFrame
        var y = screen.minY + 16
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for p in all.reversed() {
                p.animator().setFrame(NSRect(x: screen.minX + 16, y: y, width: p.frame.width, height: p.frame.height), display: true)
                y += p.frame.height + 8
            }
        }
    }

    init(file: String, image: NSImage) {
        self.file = file; self.img = image
        let w: CGFloat = 240
        let h = w * 3 / 4
        row = NSStackView(frame: NSRect(x: 8, y: 8, width: w - 16, height: 36))
        let screen = NSScreen.main!.visibleFrame
        super.init(contentRect: NSRect(x: screen.minX - w, y: screen.minY + 16, width: w, height: h), styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        level = .floating
        collectionBehavior = .canJoinAllSpaces
        isReleasedWhenClosed = false
        isMovableByWindowBackground = false
        backgroundColor = .clear
        isOpaque = false

        let thumb = DragView(frame: contentView!.bounds)
        thumb.image = image; thumb.fileURL = URL(fileURLWithPath: file)
        thumb.imageScaling = .scaleProportionallyUpOrDown
        thumb.wantsLayer = true
        thumb.layer?.cornerRadius = 8; thumb.layer?.masksToBounds = true
        thumb.layer?.borderWidth = 1; thumb.layer?.borderColor = NSColor.white.withAlphaComponent(0.6).cgColor
        contentView = thumb

        row.distribution = .fillEqually
        row.wantsLayer = true
        row.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
        row.layer?.cornerRadius = 6
        row.alphaValue = 0
        for (icon, label, sel): (String, String, Selector) in [
            ("Copy01Icon", "Copy image", #selector(copyImage)),
            ("Download04Icon", "Save to Desktop", #selector(save)),
            ("Edit02Icon", "Annotate in Preview", #selector(annotate)),
            ("Cancel01Icon", "Delete screenshot", #selector(dismiss)),
        ] {
            let url = Bundle.main.url(forResource: icon, withExtension: "svg", subdirectory: "hugeicons")!
            let image = NSImage(contentsOf: url)!
            image.size = NSSize(width: 20, height: 20)
            image.isTemplate = true
            let b = NSButton(image: image, target: self, action: sel)
            b.bezelStyle = .accessoryBarAction; b.isBordered = false; b.contentTintColor = .white
            b.toolTip = label
            b.setAccessibilityLabel(label)
            b.heightAnchor.constraint(equalToConstant: 36).isActive = true
            row.addArrangedSubview(b)
        }
        thumb.addSubview(row)
        thumb.addTrackingArea(NSTrackingArea(rect: thumb.bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil))
        orderFrontRegardless()
        Preview.all.append(self)
        Preview.layout()
    }

    override func mouseEntered(with e: NSEvent) { row.animator().alphaValue = 1 }
    override func mouseExited(with e: NSEvent) { row.animator().alphaValue = 0 }

    @objc func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        if !retainTemporaryFile { try? FileManager.default.removeItem(atPath: file) }
        Preview.all.removeAll { $0 === self }
        Preview.layout()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            animator().alphaValue = 0
            animator().setFrame(frame.offsetBy(dx: -frame.width - 16, dy: 0), display: true)
        }) { self.close() }
    }
    @objc func copyImage() { copyToClipboard([img]); dismiss() }
    @objc func save() {
        do {
            try FileManager.default.copyItem(atPath: file, toPath: newPath("png"))
            dismiss()
        } catch { NSApp.presentError(error) }
    }
    @objc func annotate() {
        // Preview owns the editing lifetime, which can outlive snip. Hand it a
        // separate temporary copy that macOS can eventually purge.
        let editingURL = FileManager.default.temporaryDirectory.appendingPathComponent("snip-edit-\(UUID().uuidString).png")
        do {
            try FileManager.default.copyItem(at: URL(fileURLWithPath: file), to: editingURL)
            NSWorkspace.shared.open([editingURL], withApplicationAt: URL(fileURLWithPath: "/System/Applications/Preview.app"), configuration: NSWorkspace.OpenConfiguration()) { _, error in
                DispatchQueue.main.async {
                    if let error {
                        try? FileManager.default.removeItem(at: editingURL)
                        NSApp.presentError(error)
                    } else { self.dismiss() }
                }
            }
        } catch { NSApp.presentError(error) }
    }
}

final class Snip: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        try? FileManager.default.removeItem(at: captureDir)
    }
    @objc func area() { capture(["-i"]) }
    @objc func fullscreen() { capture([]) }
    @objc func timed() { capture(["-T", "5"]) }

    func capture(_ flags: [String]) {
        let file: String
        do { file = try temporaryCapturePath() } catch { NSApp.presentError(error); return }
        screencapture(flags + [file]) { succeeded in
            guard succeeded, let img = NSImage(contentsOfFile: file) else {
                try? FileManager.default.removeItem(atPath: file)
                return
            }
            copyToClipboard([img])
            _ = Preview(file: file, image: img)
        }
    }

    @objc func record() { screencapture(["-i", "-J", "video", newPath("mov")]) }

    func captureTemp(_ then: @escaping (NSImage) -> Void) {
        let tmp: String
        do { tmp = try temporaryCapturePath() } catch { NSApp.presentError(error); return }
        screencapture(["-i", "-x", tmp]) { succeeded in
            defer { try? FileManager.default.removeItem(atPath: tmp) }
            if succeeded, let img = NSImage(contentsOfFile: tmp) { then(img) }
        }
    }

    @objc func ocr() {
        captureTemp { img in
            guard let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
            let req = VNRecognizeTextRequest { req, _ in
                let lines = (req.results as? [VNRecognizedTextObservation])?.compactMap { $0.topCandidates(1).first?.string } ?? []
                copyToClipboard([lines.joined(separator: "\n") as NSString])
                NSSound(named: "Tink")?.play()
            }
            req.recognitionLevel = .accurate
            try? VNImageRequestHandler(cgImage: cg).perform([req])
        }
    }

    @objc func annotate() { Preview.all.last?.annotate() }

    @objc func toggleDesktop() {
        let d = UserDefaults(suiteName: "com.apple.finder")!
        let hidden = d.object(forKey: "CreateDesktop") as? Bool == false
        d.set(hidden, forKey: "CreateDesktop")
        Process.launchedProcess(launchPath: "/usr/bin/killall", arguments: ["Finder"])
    }

    @objc func quit() { NSApp.terminate(nil) }
}

let snip = Snip()
func hotkey(_ id: UInt32, _ key: Int) {
    var ref: EventHotKeyRef?
    RegisterEventHotKey(UInt32(key), UInt32(cmdKey | shiftKey), EventHotKeyID(signature: 0x534E4950, id: id), GetApplicationEventTarget(), 0, &ref)
}

InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
    var hk = EventHotKeyID()
    GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
    snip.perform(items[Int(hk.id)].1)
    return noErr
}, 1, [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))], nil, nil)

let items: [(String, Selector, String, Int?)] = [
    ("Capture Area / Window", #selector(Snip.area), "4", kVK_ANSI_4),
    ("Capture Fullscreen", #selector(Snip.fullscreen), "3", kVK_ANSI_3),
    ("Capture After 5s", #selector(Snip.timed), "6", kVK_ANSI_6),
    ("Record Screen", #selector(Snip.record), "5", kVK_ANSI_5),
    ("Capture Text (OCR)", #selector(Snip.ocr), "2", kVK_ANSI_2),
    ("Annotate Last Screenshot", #selector(Snip.annotate), "a", kVK_ANSI_A),
    ("Toggle Desktop Icons", #selector(Snip.toggleDesktop), "d", kVK_ANSI_D),
    ("Quit snip", #selector(Snip.quit), "", nil),
]

let menu = NSMenu()
for (i, (title, sel, key, code)) in items.enumerated() {
    let m = NSMenuItem(title: title, action: sel, keyEquivalent: key)
    m.keyEquivalentModifierMask = [.command, .shift]
    m.target = snip
    menu.addItem(m)
    if let code { hotkey(UInt32(i), code) }
}

let app = NSApplication.shared
app.delegate = snip
app.setActivationPolicy(.accessory)
let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
let icon = NSImage(contentsOf: Bundle.main.url(forResource: "icon", withExtension: "svg")!)!
icon.isTemplate = true
icon.size = NSSize(width: 18, height: 18)
status.button?.image = icon
status.menu = menu
app.run()
