import AppKit

let side: CGFloat = 1024
let inset: CGFloat = 100
let box = CGRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)

func squircle(_ r: CGRect, n: Double = 5, steps: Int = 720) -> CGPath {
    let p = CGMutablePath()
    let (a, b) = (r.width / 2, r.height / 2)
    let c = CGPoint(x: r.midX, y: r.midY)
    for i in 0...steps {
        let t = Double(i) / Double(steps) * 2 * .pi
        let (ct, st) = (cos(t), sin(t))
        let x = pow(abs(ct), 2 / n) * a * (ct < 0 ? -1 : 1)
        let y = pow(abs(st), 2 / n) * b * (st < 0 ? -1 : 1)
        let pt = CGPoint(x: c.x + x, y: c.y + y)
        i == 0 ? p.move(to: pt) : p.addLine(to: pt)
    }
    p.closeSubpath()
    return p
}

let svg = try String(contentsOfFile: "icon.svg", encoding: .utf8).replacingOccurrences(of: "#000", with: "#fff")
let glyph = NSImage(data: svg.data(using: .utf8)!)!

func render() -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(side), pixelsHigh: Int(side),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let shape = squircle(box)
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [CGColor(red: 0.267, green: 0.267, blue: 0.278, alpha: 1),
                                   CGColor(red: 0.129, green: 0.129, blue: 0.141, alpha: 1)] as CFArray,
                          locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: box.maxY), end: CGPoint(x: 0, y: box.minY), options: [])
    ctx.restoreGState()
    ctx.addPath(shape)
    ctx.setLineWidth(4)
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.14))
    ctx.strokePath()
    NSGraphicsContext.current!.imageInterpolation = .high
    glyph.draw(in: box.insetBy(dx: box.width * 0.22, dy: box.height * 0.22))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let master = NSImage(size: NSSize(width: side, height: side))
master.addRepresentation(render())

let fm = FileManager.default
let set = URL(fileURLWithPath: "build/AppIcon.iconset")
try? fm.removeItem(at: set)
try fm.createDirectory(at: set, withIntermediateDirectories: true)
let sizes = [(16, "16x16"), (32, "16x16@2x"), (32, "32x32"), (64, "32x32@2x"),
             (128, "128x128"), (256, "128x128@2x"), (256, "256x256"),
             (512, "256x256@2x"), (512, "512x512"), (1024, "512x512@2x")]
for (px, name) in sizes {
    let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
    NSGraphicsContext.current!.imageInterpolation = .high
    master.draw(in: CGRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    try out.representation(using: .png, properties: [:])!.write(to: set.appendingPathComponent("icon_\(name).png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", set.path, "-o", "AppIcon.icns"]
try p.run(); p.waitUntilExit()
exit(p.terminationStatus)
