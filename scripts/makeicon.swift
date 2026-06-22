import AppKit

// Generates an .iconset of a gradient squircle with a white game-controller glyph.
// Usage: swift makeicon.swift <iconset-dir>

let iconsetDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

func whiteSymbol(_ name: String, pointSize: CGFloat) -> NSImage? {
    let cfg = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
    guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil),
          let sym = base.withSymbolConfiguration(cfg) else { return nil }
    let s = sym.size
    let out = NSImage(size: s)
    out.lockFocus()
    sym.draw(in: NSRect(origin: .zero, size: s))
    NSColor.white.set()
    NSRect(origin: .zero, size: s).fill(using: .sourceAtop)
    out.unlockFocus()
    return out
}

func renderPNG(_ px: Int) -> Data? {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let size = CGFloat(px)
    let inset = size * 0.045
    let bg = NSRect(x: 0, y: 0, width: size, height: size).insetBy(dx: inset, dy: inset)
    let radius = bg.width * 0.2237
    let path = NSBezierPath(roundedRect: bg, xRadius: radius, yRadius: radius)
    let gradient = NSGradient(starting: NSColor(srgbRed: 0.45, green: 0.24, blue: 0.97, alpha: 1),
                              ending: NSColor(srgbRed: 0.16, green: 0.47, blue: 0.99, alpha: 1))!
    path.addClip()
    gradient.draw(in: bg, angle: -90)

    if let glyph = whiteSymbol("gamecontroller.fill", pointSize: size * 0.44) {
        let s = glyph.size
        let origin = NSPoint(x: (size - s.width) / 2, y: (size - s.height) / 2)
        glyph.draw(in: NSRect(origin: origin, size: s))
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let targets: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

for (name, px) in targets {
    guard let data = renderPNG(px) else { print("FAIL \(name)"); continue }
    try? data.write(to: URL(fileURLWithPath: "\(iconsetDir)/\(name)"))
}
print("wrote \(targets.count) PNGs to \(iconsetDir)")
