import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct TokenColor: Decodable {
    let hex: String
    let alpha: Double

    var cgColor: CGColor {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0
        return CGColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: CGFloat(alpha)
        )
    }
}

struct TokenShadow: Decodable {
    let color: TokenColor
}

struct Tokens: Decodable {
    let color: [String: TokenColor]
    let shadow: [String: [TokenShadow]]
}

struct Mark {
    let unit: CGFloat
    let rings: [CGFloat]
    let stroke: CGFloat
    let dot: CGFloat

    static func forPixels(_ pixels: Int) -> Mark {
        switch pixels {
        case ..<24: Mark(unit: 30, rings: [8], stroke: 3.4, dot: 3)
        case ..<48: Mark(unit: 27, rings: [9, 4.7], stroke: 2.3, dot: 1.7)
        default: Mark(unit: 25, rings: [9, 5], stroke: 2, dot: 2.2)
        }
    }
}

struct Slot {
    let points: Int
    let scale: Int

    var pixels: Int { points * scale }
    var filename: String {
        scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@\(scale)x.png"
    }
}

let canvas: CGFloat = 1024
let margin: CGFloat = 100
let cornerRadius: CGFloat = 185
let sideHeight: CGFloat = 56
let shadowOffset: CGFloat = 12
let shadowBlur: CGFloat = 28

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let tokensURL = root.appending(path: "design-system-prototypes/tokens/tecla.json")
let iconset = root.appending(path: "DailyZGT/Resources/Icons.xcassets/AppIcon.appiconset")
let tokens = try JSONDecoder().decode(Tokens.self, from: Data(contentsOf: tokensURL))

func color(_ name: String) -> CGColor {
    guard let token = tokens.color[name] else {
        FileHandle.standardError.write(Data("tecla.json has no color \(name)\n".utf8))
        exit(1)
    }
    return token.cgColor
}

func shadowColor(_ name: String) -> CGColor {
    guard let layer = tokens.shadow[name]?.first else {
        FileHandle.standardError.write(Data("tecla.json has no shadow \(name)\n".utf8))
        exit(1)
    }
    return layer.color.cgColor
}

func key(y: CGFloat) -> CGPath {
    let side = canvas - margin * 2
    let rect = CGRect(x: margin, y: y, width: side, height: side - sideHeight)
    return CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
}

func render(pixels: Int) -> CGImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let scale = CGFloat(pixels) / canvas
    context.scaleBy(x: scale, y: scale)
    context.interpolationQuality = .high

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -shadowOffset * scale),
        blur: shadowBlur * scale,
        color: shadowColor("alert")
    )
    context.addPath(key(y: margin))
    context.setFillColor(color("fillSide"))
    context.fillPath()
    context.restoreGState()

    context.addPath(key(y: margin + sideHeight))
    context.setFillColor(color("fill"))
    context.fillPath()

    let mark = Mark.forPixels(pixels)
    let center = CGPoint(x: canvas / 2, y: margin + sideHeight + (canvas - margin * 2 - sideHeight) / 2)
    context.setStrokeColor(color("onFill"))
    context.setLineWidth(mark.stroke * mark.unit)
    for ring in mark.rings {
        let radius = ring * mark.unit
        context.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
    let dot = mark.dot * mark.unit
    context.setFillColor(color("accent"))
    context.fillEllipse(in: CGRect(x: center.x - dot, y: center.y - dot, width: dot * 2, height: dot * 2))

    return context.makeImage()!
}

func write(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw CocoaError(.fileWriteUnknown)
    }
}

let slots = [16, 32, 128, 256, 512].flatMap { points in [1, 2].map { Slot(points: points, scale: $0) } }

try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for slot in slots {
    try write(render(pixels: slot.pixels), to: iconset.appending(path: slot.filename))
}

let contents: [String: Any] = [
    "images": slots.map { slot in
        [
            "filename": slot.filename,
            "idiom": "mac",
            "scale": "\(slot.scale)x",
            "size": "\(slot.points)x\(slot.points)",
        ]
    },
    "info": ["author": "xcode", "version": 1],
]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: iconset.appending(path: "Contents.json"))
print("Wrote \(slots.count) PNG files to \(iconset.path.replacingOccurrences(of: root.path + "/", with: "")).")
