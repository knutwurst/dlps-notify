import AppKit
import SwiftUI

// your own icons from the folder if there are any, colored pills otherwise.
// no logos shipped, not my trademarks.
enum PlatformStyle {
    private static let rgb: [String: (r: Double, g: Double, b: Double)] = [
        "PS5": (0.18, 0.44, 0.93),   // blue
        "PS4": (0.16, 0.60, 0.33),   // green
        "PS3": (0.56, 0.36, 0.88),   // purple
        "PS2": (0.82, 0.47, 0.12),   // orange
        "PSN": (0.84, 0.27, 0.31),   // red
    ]
    private static let fallback = (r: 0.40, g: 0.40, b: 0.44)

    static func nsColor(forName name: String) -> NSColor {
        let c = rgb[name] ?? fallback
        return NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: 1)
    }

    static func color(forName name: String) -> Color {
        let c = rgb[name] ?? fallback
        return Color(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: 1)
    }

    static func isKnown(_ name: String) -> Bool { rgb[name] != nil }

    // MARK: - Custom icons

    // ps5.png, ps4.png, ...
    static var iconsFolderURL: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("DLPSNotify/platforms", isDirectory: true)
    }

    static func ensureIconsFolder() {
        try? FileManager.default.createDirectory(at: iconsFolderURL, withIntermediateDirectories: true)
    }

    private static var iconCache: [String: NSImage?] = [:]
    static func clearIconCache() { iconCache = [:] }

    static func iconImage(forName name: String) -> NSImage? {
        if let cached = iconCache[name] { return cached }
        let image = loadIcon(forName: name)
        iconCache[name] = image
        return image
    }

    private static func loadIcon(forName name: String) -> NSImage? {
        let base = name.lowercased()
        let extensions = ["png", "pdf", "jpg", "jpeg", "tiff"]
        for ext in extensions {
            let url = iconsFolderURL.appendingPathComponent("\(base).\(ext)")
            if let image = NSImage(contentsOf: url) { return image }
        }
        for ext in extensions {
            if let path = Bundle.main.path(forResource: base, ofType: ext, inDirectory: "platforms"),
               let image = NSImage(contentsOfFile: path) {
                return image
            }
        }
        return nil
    }

    static func menuImage(forName name: String) -> NSImage? {
        if let icon = iconImage(forName: name) { return fitted(icon, maxWidth: 26, maxHeight: 14) }
        return menuBadge(forName: name)
    }

    private static func fitted(_ image: NSImage, maxWidth: CGFloat, maxHeight: CGFloat) -> NSImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let scale = min(maxWidth / size.width, maxHeight / size.height)
        let target = NSSize(width: size.width * scale, height: size.height * scale)
        let out = NSImage(size: target)
        out.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: target), from: .zero,
                   operation: .sourceOver, fraction: 1.0, respectFlipped: true,
                   hints: [.interpolation: NSImageInterpolation.high])
        out.unlockFocus()
        return out
    }

    // drawn at 2x, otherwise it looks like mush on retina
    static func menuBadge(forName name: String) -> NSImage? {
        guard isKnown(name) else { return nil }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .heavy),
            .foregroundColor: NSColor.white,
            .kern: 0.4,
        ]
        let text = name as NSString
        let textSize = text.size(withAttributes: attributes)
        let height: CGFloat = 14
        let width = ceil(textSize.width) + 11
        let scale: CGFloat = 2

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        rep.size = NSSize(width: width, height: height)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let rect = NSRect(x: 0, y: 0, width: width, height: height)
        NSBezierPath(roundedRect: rect, xRadius: height / 2, yRadius: height / 2).addClip()
        nsColor(forName: name).setFill()
        rect.fill()
        text.draw(at: NSPoint(x: (width - textSize.width) / 2,
                              y: (height - textSize.height) / 2),
                  withAttributes: attributes)
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(rep)
        return image
    }
}
