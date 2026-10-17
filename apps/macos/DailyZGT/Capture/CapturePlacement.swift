import AppKit

struct ScreenGeometry: Equatable {
    var frame: CGRect
    var visibleFrame: CGRect
}

enum CapturePlacement {
    static func frame(size: CGSize, mouse: CGPoint, screens: [ScreenGeometry], topInset: CGFloat = Theme.Capture.topInset) -> CGRect {
        guard let screen = screens.first(where: { $0.frame.contains(mouse) }) ?? screens.first else {
            return CGRect(origin: .zero, size: size)
        }
        let visible = screen.visibleFrame
        let x = min(max(visible.midX - size.width / 2, visible.minX), max(visible.maxX - size.width, visible.minX))
        let y = max(visible.maxY - topInset - size.height, visible.minY)
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    @MainActor
    static func currentScreens() -> [ScreenGeometry] {
        NSScreen.screens.map { ScreenGeometry(frame: $0.frame, visibleFrame: $0.visibleFrame) }
    }
}
