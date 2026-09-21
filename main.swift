import Cocoa
import Carbon
import Vision

let saveDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")

func newPath(_ ext: String) -> String {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
    return saveDir.appendingPathComponent("Screenshot \(f.string(from: Date())).\(ext)").path
}

func screencapture(_ args: [String], then: @escaping () -> Void = {}) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    p.arguments = args
    p.terminationHandler = { p in if p.terminationStatus == 0 { DispatchQueue.main.async(execute: then) } }
    try? p.run()
}

func copyToClipboard(_ items: [NSPasteboardWriting]) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.writeObjects(items)
}

final class PinView: NSImageView {
    override func mouseDown(with e: NSEvent) { if e.clickCount == 2 { window?.close() } }
}

final class DragView: NSImageView, NSDraggingSource {
    var fileURL: URL!
    override func mouseDragged(with e: NSEvent) {
        let item = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
        item.setDraggingFrame(bounds, contents: image)
        beginDraggingSession(with: [item], event: e, source: self)
    }
    override func mouseUp(with e: NSEvent) { if e.clickCount == 2 { (window as? Preview)?.annotate() } }
    func draggingSession(_ s: NSDraggingSession, sourceOperationMaskFor c: NSDraggingContext) -> NSDragOperation { .copy }
}

final class Preview: NSPanel {
    static var all: [Preview] = []
    let file: String
    let img: NSImage
    let row: NSStackView

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
        let w: CGFloat = 200
        let h = min(160, w * image.size.height / image.size.width)
        row = NSStackView(frame: NSRect(x: 8, y: 8, width: w - 16, height: 28))
        let screen = NSScreen.main!.visibleFrame
        super.init(contentRect: NSRect(x: screen.minX - w, y: screen.minY + 16, width: w, height: h), styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        level = .floating
        collectionBehavior = .canJoinAllSpaces
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
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
        row.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        row.layer?.cornerRadius = 6
        row.alphaValue = 0
        for (sym, sel): (String, Selector) in [
            ("xmark", #selector(dismiss)), ("doc.on.doc", #selector(copyImage)), ("pencil.tip.crop.circle", #selector(annotate)),
            ("pin", #selector(pinIt)), ("trash", #selector(trash)),
        ] {
            let b = NSButton(image: NSImage(systemSymbolName: sym, accessibilityDescription: nil)!, target: self, action: sel)
            b.bezelStyle = .accessoryBarAction; b.isBordered = false; b.contentTintColor = .white
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
        Preview.all.removeAll { $0 === self }
        Preview.layout()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            animator().alphaValue = 0
            animator().setFrame(frame.offsetBy(dx: -frame.width - 16, dy: 0), display: true)
        }) { self.close() }
    }
    @objc func copyImage() { copyToClipboard([img]); dismiss() }
    @objc func annotate() {
        NSWorkspace.shared.open([URL(fileURLWithPath: file)], withApplicationAt: URL(fileURLWithPath: "/System/Applications/Preview.app"), configuration: NSWorkspace.OpenConfiguration())
        dismiss()
    }
    @objc func pinIt() { snip.showPin(img); dismiss() }
    @objc func trash() {
        try? FileManager.default.trashItem(at: URL(fileURLWithPath: file), resultingItemURL: nil)
        dismiss()
    }
}

final class Snip: NSObject {
    @objc func area() { capture(["-i"]) }
    @objc func fullscreen() { capture([]) }
    @objc func timed() { capture(["-T", "5"]) }

    func capture(_ flags: [String]) {
        let file = newPath("png")
        screencapture(flags + [file]) {
            guard let img = NSImage(contentsOfFile: file) else { return }
            copyToClipboard([img])
            _ = Preview(file: file, image: img)
        }
    }

    @objc func record() { screencapture(["-i", "-J", "video", newPath("mov")]) }

    func captureTemp(_ then: @escaping (NSImage) -> Void) {
        let tmp = NSTemporaryDirectory() + "snip-\(Date().timeIntervalSince1970).png"
        screencapture(["-i", "-x", tmp]) { if let img = NSImage(contentsOfFile: tmp) { then(img) } }
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

    @objc func pin() { captureTemp(showPin) }

    func showPin(_ img: NSImage) {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let size = NSSize(width: img.size.width / scale, height: img.size.height / scale)
        let w = NSWindow(contentRect: NSRect(origin: NSEvent.mouseLocation, size: size), styleMask: .borderless, backing: .buffered, defer: false)
        let v = PinView(frame: NSRect(origin: .zero, size: size))
        v.image = img
        w.contentView = v
        w.level = .floating
        w.isMovableByWindowBackground = true
        w.isReleasedWhenClosed = false
        w.makeKeyAndOrderFront(nil)
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
    ("Pin Screenshot", #selector(Snip.pin), "p", kVK_ANSI_P),
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
app.setActivationPolicy(.accessory)
let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
let icon = NSImage(contentsOf: Bundle.main.url(forResource: "icon", withExtension: "svg")!)!
icon.isTemplate = true
icon.size = NSSize(width: 18, height: 18)
status.button?.image = icon
status.menu = menu
app.run()
