import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum NoteImageEncoder {
    static let maxLongEdge = 2400
    static let jpegQuality = 0.85

    static func encode(_ data: Data) -> EncodedImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let full = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let image = max(full.width, full.height) > maxLongEdge ? downscaled(source) ?? full : full
        let alpha = hasAlpha(image)
        let type = alpha ? UTType.png : UTType.jpeg
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil) else {
            return nil
        }
        let options: [CFString: Any] = alpha ? [:] : [kCGImageDestinationLossyCompressionQuality: jpegQuality]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return EncodedImage(
            mime: alpha ? "image/png" : "image/jpeg",
            width: image.width,
            height: image.height,
            bytes: output as Data
        )
    }

    static func hasAlpha(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            false
        default:
            true
        }
    }

    private static func downscaled(_ source: CGImageSource) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxLongEdge,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
