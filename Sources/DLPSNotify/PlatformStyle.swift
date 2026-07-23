import AppKit
import SwiftUI

/// Colour-coded platform badges so platforms are distinguishable at a glance.
/// (Sony's real PS logos are trademarks, so we use our own colour coding instead.)
enum PlatformStyle {
    // Distinct hues per platform — functional colour coding, not official brand colours.
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

    /// A small coloured pill (region code in white) for use as an NSMenuItem image.
    static func menuBadge(forName name: String) -> NSImage? {
        guard isKnown(name) else { return nil }
        let size = NSSize(width: 34, height: 14)
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
        NSBezierPath(roundedRect: rect, xRadius: 3.5, yRadius: 3.5).addClip()
        nsColor(forName: name).setFill()
        rect.fill()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let text = name as NSString
        let textSize = text.size(withAttributes: attributes)
        text.draw(at: NSPoint(x: (size.width - textSize.width) / 2,
                              y: (size.height - textSize.height) / 2 - 0.5),
                  withAttributes: attributes)
        image.unlockFocus()
        return image
    }
}
