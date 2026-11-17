import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import DailyZGT

enum TestImages {
    static func cgImage(width: Int, height: Int, alpha: Bool) -> CGImage {
        let info = alpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: info
        )!
        context.setFillColor(CGColor(srgbRed: 0.51, green: 0.22, blue: 0.93, alpha: alpha ? 0.5 : 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(srgbRed: 1, green: 0.75, blue: 0.04, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height / 2))
        return context.makeImage()!
    }

    static func png(width: Int, height: Int, alpha: Bool) -> Data {
        encode(cgImage(width: width, height: height, alpha: alpha), as: .png)
    }

    static func jpeg(width: Int, height: Int) -> Data {
        encode(cgImage(width: width, height: height, alpha: false), as: .jpeg)
    }

    private static func encode(_ image: CGImage, as type: UTType) -> Data {
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }
}

@Suite
struct NoteImageEncoderTests {
    private func decoded(_ image: EncodedImage) throws -> CGImage {
        let source = try #require(CGImageSourceCreateWithData(image.bytes as CFData, nil))
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    @Test
    func anImageWithAlphaStaysPNG() throws {
        let encoded = try #require(NoteImageEncoder.encode(TestImages.png(width: 300, height: 200, alpha: true)))
        #expect(encoded.mime == "image/png")
        #expect(encoded.width == 300)
        #expect(encoded.height == 200)
        #expect(NoteImageEncoder.hasAlpha(try decoded(encoded)))
    }

    @Test
    func anOpaqueImageBecomesJPEG() throws {
        let encoded = try #require(NoteImageEncoder.encode(TestImages.png(width: 300, height: 200, alpha: false)))
        #expect(encoded.mime == "image/jpeg")
        #expect(encoded.bytes.starts(with: [0xFF, 0xD8]))
        #expect(encoded.width == 300)
    }

    @Test
    func aWideImageShrinksToTheLongEdgeLimit() throws {
        let encoded = try #require(NoteImageEncoder.encode(TestImages.jpeg(width: 3600, height: 1200)))
        #expect(encoded.width == 2400)
        #expect(encoded.height == 800)
        let image = try decoded(encoded)
        #expect(image.width == 2400)
        #expect(image.height == 800)
    }

    @Test
    func aTallImageShrinksByItsHeight() throws {
        let encoded = try #require(NoteImageEncoder.encode(TestImages.png(width: 1000, height: 4000, alpha: true)))
        #expect(encoded.height == 2400)
        #expect(encoded.width == 600)
        #expect(encoded.mime == "image/png")
    }

    @Test
    func dataThatIsNotAnImageGivesNothing() {
        #expect(NoteImageEncoder.encode(Data("no image".utf8)) == nil)
    }
}
