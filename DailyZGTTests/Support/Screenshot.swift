import AppKit
import SwiftUI

enum ScreenshotError: Error {
    case repositoryRootNotFound
    case renderFailed
    case encodeFailed
}

@MainActor
enum Screenshot {
    @discardableResult
    static func write(_ view: some View, named name: String, scale: CGFloat = 2) throws -> URL {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark))
        renderer.scale = scale
        guard let image = renderer.cgImage else {
            throw ScreenshotError.renderFailed
        }
        guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw ScreenshotError.encodeFailed
        }
        return try save(data, named: name)
    }

    @discardableResult
    static func writeHosted(_ view: some View, named name: String, scale: Int = 2) throws -> URL {
        let hosting = NSHostingView(rootView: view.environment(\.colorScheme, .dark))
        hosting.appearance = NSAppearance(named: .darkAqua)
        let size = hosting.fittingSize
        let frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = hosting
        hosting.frame = frame
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int((size.width * CGFloat(scale)).rounded(.up)),
            pixelsHigh: Int((size.height * CGFloat(scale)).rounded(.up)),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw ScreenshotError.renderFailed
        }
        rep.size = size
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw ScreenshotError.encodeFailed
        }
        return try save(data, named: name)
    }

    private static func save(_ data: Data, named name: String) throws -> URL {
        let directory = try repositoryRoot().appending(path: "build/screens", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "\(name).png")
        try data.write(to: url)
        return url
    }

    private static func repositoryRoot(filePath: String = #filePath) throws -> URL {
        var directory = URL(filePath: filePath).deletingLastPathComponent()
        while directory.path != "/" {
            if FileManager.default.fileExists(atPath: directory.appending(path: "project.yml").path) {
                return directory
            }
            directory = directory.deletingLastPathComponent()
        }
        throw ScreenshotError.repositoryRootNotFound
    }
}
