// Renders the Optics app icon (two offset lens rings on a dark squircle) to an .iconset.
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let inset = s * 0.1
    let tile = NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset),
                            xRadius: s * 0.18, yRadius: s * 0.18)
    NSGradient(colors: [NSColor(red: 0.09, green: 0.10, blue: 0.16, alpha: 1), NSColor(red: 0.03, green: 0.03, blue: 0.06, alpha: 1)])!
        .draw(in: tile, angle: -90)
    let c = NSPoint(x: s / 2, y: s / 2)
    let r = s * 0.25
    let ring = NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    ring.lineWidth = s * 0.055
    NSGraphicsContext.current?.saveGraphicsState()
    let stroked = ring.copy() as! NSBezierPath
    NSColor(red: 0.36, green: 0.42, blue: 1, alpha: 1).setStroke()
    stroked.stroke()
    NSGraphicsContext.current?.restoreGraphicsState()
    let r2 = r * 0.45
    let dot = NSBezierPath(ovalIn: NSRect(x: c.x - r2 + r * 0.22, y: c.y - r2 + r * 0.22, width: 2 * r2, height: 2 * r2))
    NSGradient(colors: [NSColor(red: 0.93, green: 0.36, blue: 0.86, alpha: 1), NSColor(red: 0.18, green: 0.77, blue: 1, alpha: 1)])!
        .draw(in: dot, angle: -60)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                   ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    try! render(px).write(to: out.appendingPathComponent("icon_\(name).png"))
}
