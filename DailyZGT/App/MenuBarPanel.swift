import AppKit

@MainActor
enum MenuBarPanel {
    static var isOpen: Bool {
        NSApp.windows.contains { $0.isVisible && $0.className.contains("MenuBarExtraWindow") }
    }

    static func open(retries: Int = 3) {
        NSApp.activate()
        guard !isOpen else { return }
        if let button = statusButton {
            button.performClick(nil)
        } else if retries > 0 {
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                open(retries: retries - 1)
            }
        }
    }

    private static var statusButton: NSStatusBarButton? {
        NSApp.windows.lazy.compactMap { button(in: $0.contentView) }.first
    }

    private static func button(in view: NSView?) -> NSStatusBarButton? {
        guard let view else { return nil }
        if let button = view as? NSStatusBarButton {
            return button
        }
        return view.subviews.lazy.compactMap { button(in: $0) }.first
    }
}
