import AppKit
import SwiftUI

final class HoverAreaView: NSView {
    var onChange: @MainActor (Bool) -> Void = { _ in }
    private var isInside = false

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
        refresh()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refresh()
    }

    override func mouseEntered(with event: NSEvent) {
        set(true)
    }

    override func mouseExited(with event: NSEvent) {
        set(false)
    }

    private func refresh() {
        guard let window else {
            set(false)
            return
        }
        let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        set(visibleRect.contains(point))
    }

    private func set(_ inside: Bool) {
        guard inside != isInside else { return }
        isInside = inside
        let onChange = onChange
        Task { @MainActor in onChange(inside) }
    }
}

struct HoverArea: NSViewRepresentable {
    let onChange: @MainActor (Bool) -> Void

    func makeNSView(context: Context) -> HoverAreaView {
        let view = HoverAreaView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ view: HoverAreaView, context: Context) {
        view.onChange = onChange
    }
}

extension View {
    func hoverArea(_ onChange: @escaping @MainActor (Bool) -> Void) -> some View {
        background(HoverArea(onChange: onChange))
    }

    func linkCursor() -> some View {
        onContinuousHover { phase in
            switch phase {
            case .active: NSCursor.pointingHand.set()
            case .ended: NSCursor.arrow.set()
            }
        }
    }
}
