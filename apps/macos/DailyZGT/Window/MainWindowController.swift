import AppKit
import SwiftUI

@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    static let shared = MainWindowController()

    private(set) var window: NSWindow?

    func show(store: AppStore, alerts: AlertCoordinator?, panel: PanelState) {
        let window = window ?? makeWindow(store: store, alerts: alerts, panel: panel)
        self.window = window
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func makeWindow(store: AppStore, alerts: AlertCoordinator?, panel: PanelState) -> NSWindow {
        let state = PanelState(store: store, loginItem: panel.loginItem, shortcut: panel.shortcut)
        let root = MainWindowView()
            .environment(store)
            .environment(state)
            .environment(alerts)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Theme.Window.defaultWidth, height: Theme.Window.defaultHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = MainWindowView.title
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(Theme.Panel.background)
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: Theme.Window.minWidth, height: Theme.Window.minHeight)
        window.contentView = NSHostingView(rootView: root)
        window.delegate = self
        window.center()
        window.setFrameAutosaveName(Theme.Window.autosaveName)
        return window
    }
}
