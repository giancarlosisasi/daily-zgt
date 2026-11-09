import AppKit
import SwiftUI

enum DragStartRule {
    static func hasMoved(from start: CGPoint, to end: CGPoint) -> Bool {
        hypot(end.x - start.x, end.y - start.y) >= Theme.DragPreview.startDistance
    }
}

final class DragHandleView: NSView, NSDraggingSource {
    var payload = ""
    var makeImage: (CGFloat) -> NSImage? = { _ in nil }
    var onStart: () -> Void = {}
    var onEnd: () -> Void = {}
    private var downEvent: NSEvent?

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.cursorUpdate, .activeAlways, .inVisibleRect], owner: self))
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.openHand.set()
    }

    override func mouseDown(with event: NSEvent) {
        downEvent = event
        NSCursor.closedHand.set()
    }

    override func mouseUp(with event: NSEvent) {
        downEvent = nil
        NSCursor.openHand.set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let down = downEvent, DragStartRule.hasMoved(from: down.locationInWindow, to: event.locationInWindow) else {
            return
        }
        downEvent = nil
        startSession(with: down)
    }

    private func startSession(with event: NSEvent) {
        let item = NSPasteboardItem()
        item.setString(payload, forType: .string)
        let dragging = NSDraggingItem(pasteboardWriter: item)
        let image = makeImage(window?.backingScaleFactor ?? 2) ?? NSImage(size: bounds.size)
        let point = convert(event.locationInWindow, from: nil)
        dragging.setDraggingFrame(
            NSRect(
                x: point.x - Theme.DragPreview.grabOffset,
                y: point.y - image.size.height / 2,
                width: image.size.width,
                height: image.size.height
            ),
            contents: image
        )
        onStart()
        let session = beginDraggingSession(with: [dragging], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .withinApplication ? .move : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        onEnd()
    }
}

struct DragHandle: NSViewRepresentable {
    let payload: String
    let makeImage: (CGFloat) -> NSImage?
    let onStart: () -> Void
    let onEnd: () -> Void

    func makeNSView(context: Context) -> DragHandleView {
        let view = DragHandleView()
        view.setAccessibilityElement(false)
        return view
    }

    func updateNSView(_ view: DragHandleView, context: Context) {
        view.payload = payload
        view.makeImage = makeImage
        view.onStart = onStart
        view.onEnd = onEnd
    }
}

struct DragPreview: View {
    let title: String
    let level: PriorityLevel

    var body: some View {
        HStack(spacing: Theme.DragPreview.spacing) {
            IconView(icon: .dragHandle, size: Theme.Row.handleIconSize)
                .foregroundStyle(Theme.Text.dim)
            Text(title)
                .font(Theme.Font.bodyStrong)
                .foregroundStyle(Theme.Text.primary)
                .lineLimit(1)
            LevelBars(level: level)
        }
        .padding(.horizontal, Theme.DragPreview.horizontalPadding)
        .padding(.vertical, Theme.DragPreview.verticalPadding)
        .background(Theme.DragPreview.background, in: RoundedRectangle(cornerRadius: Theme.DragPreview.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.DragPreview.radius, style: .continuous)
                .strokeBorder(Theme.DragPreview.border, lineWidth: Theme.DragPreview.borderWidth)
        )
        .environment(\.colorScheme, .dark)
    }

    @MainActor
    static func image(title: String, level: PriorityLevel, scale: CGFloat) -> NSImage? {
        let renderer = ImageRenderer(content: DragPreview(title: title, level: level))
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(width: Theme.DragPreview.maxWidth, height: nil)
        return renderer.nsImage
    }
}
