import AppKit
import SwiftUI

final class ClickableTitleView: NSTextView {
    var onOpen: () -> Void = {}
    private var appliedText: String?
    private var appliedUnderline = false

    static func make() -> ClickableTitleView {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: 100, height: CGFloat.greatestFiniteMagnitude))
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        let view = ClickableTitleView(frame: .zero, textContainer: container)
        view.isEditable = false
        view.isSelectable = true
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.isVerticallyResizable = false
        view.isHorizontallyResizable = false
        view.setAccessibilityRole(.button)
        return view
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        let down = event.locationInWindow
        super.mouseDown(with: event)
        let release = NSApp.currentEvent
        let up = release?.type == .leftMouseUp ? release?.locationInWindow ?? down : down
        if TitleClickRule.shouldOpen(down: down, up: up, selectionLength: selectedRange().length) {
            onOpen()
        }
    }

    override func accessibilityPerformPress() -> Bool {
        onOpen()
        return true
    }

    func apply(text: String, isUnderlined: Bool) {
        guard let storage = textStorage else { return }
        if appliedText != text {
            let style = NSMutableParagraphStyle()
            style.minimumLineHeight = Theme.Font.rowTitleLineHeight
            style.maximumLineHeight = Theme.Font.rowTitleLineHeight
            let attributes: [NSAttributedString.Key: Any] = [
                .font: Theme.Font.rowTitle,
                .foregroundColor: NSColor(Theme.Text.primary),
                .paragraphStyle: style,
            ]
            storage.setAttributedString(NSAttributedString(string: text, attributes: attributes))
            appliedText = text
            appliedUnderline = false
            setAccessibilityLabel(text)
        }
        guard appliedUnderline != isUnderlined else { return }
        let range = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        if isUnderlined {
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            storage.addAttribute(.underlineColor, value: NSColor(Theme.Row.titleUnderline), range: range)
        } else {
            storage.removeAttribute(.underlineStyle, range: range)
            storage.removeAttribute(.underlineColor, range: range)
        }
        storage.endEditing()
        appliedUnderline = isUnderlined
    }

    func size(fittingWidth width: CGFloat) -> CGSize {
        guard let container = textContainer, let layout = layoutManager else { return .zero }
        container.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        layout.ensureLayout(for: container)
        let used = layout.usedRect(for: container)
        return CGSize(width: ceil(used.width), height: ceil(used.height))
    }
}

struct SelectableTitle: NSViewRepresentable {
    let text: String
    let isUnderlined: Bool
    let onOpen: () -> Void

    func makeNSView(context: Context) -> ClickableTitleView {
        ClickableTitleView.make()
    }

    func updateNSView(_ view: ClickableTitleView, context: Context) {
        view.onOpen = onOpen
        view.apply(text: text, isUnderlined: isUnderlined)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: ClickableTitleView, context: Context) -> CGSize? {
        nsView.apply(text: text, isUnderlined: isUnderlined)
        let size = nsView.size(fittingWidth: proposal.width ?? 10_000)
        return CGSize(width: proposal.width ?? size.width, height: size.height)
    }
}
