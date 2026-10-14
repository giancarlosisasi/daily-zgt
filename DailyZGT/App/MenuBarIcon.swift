import AppKit
import SwiftUI

enum MenuBarIcon {
    static let size: CGFloat = 16
    private static let viewBox: CGFloat = 24
    private static let strokeWidth: CGFloat = 2

    static func makeImage() -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            let scale = rect.width / viewBox
            NSColor.black.set()
            for radius: CGFloat in [9, 5] {
                circle(radius: radius, scale: scale).stroke()
            }
            let dot = circle(radius: 1.2, scale: scale)
            dot.fill()
            dot.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func circle(radius: CGFloat, scale: CGFloat) -> NSBezierPath {
        let center = viewBox / 2 * scale
        let r = radius * scale
        let path = NSBezierPath(ovalIn: NSRect(x: center - r, y: center - r, width: r * 2, height: r * 2))
        path.lineWidth = strokeWidth * scale
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        return path
    }
}
