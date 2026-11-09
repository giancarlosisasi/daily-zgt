import AppKit
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct MainWindowTests {
    let clock = TestClock("2026-10-12T10:24:00")

    @Test
    func openingTheWindowShowsItOnceAndClosingItHidesTheDockIcon() throws {
        let store = try makeStore(clock)
        let panel = PanelState(store: store)
        let controller = MainWindowController()

        controller.show(store: store, alerts: nil, panel: panel)
        let window = try #require(controller.window)
        #expect(window.isVisible)
        #expect(window.title == "Daily ZGT")
        #expect(window.contentMinSize == NSSize(width: Theme.Window.minWidth, height: Theme.Window.minHeight))
        #expect(NSApp.activationPolicy() == .regular)

        controller.show(store: store, alerts: nil, panel: panel)
        #expect(controller.window === window)

        window.close()
        #expect(!window.isVisible)
        #expect(NSApp.activationPolicy() == .accessory)
    }

    @Test
    func theWindowHasItsOwnNavigation() throws {
        let store = try makeStore(clock)
        let panel = PanelState(store: store)
        let first = try store.addPriority(title: "First", list: .today)
        let window = PanelState(store: store, loginItem: panel.loginItem, shortcut: panel.shortcut)

        window.openDetail(first.id)
        #expect(window.detailPriority?.id == first.id)
        #expect(panel.detailPriority == nil)
    }
}

@Suite
@MainActor
struct HoverAreaTests {
    @Test
    func enterAndExitReportOnceEach() async throws {
        let view = HoverAreaView()
        var changes: [Bool] = []
        view.onChange = { changes.append($0) }
        let event = try #require(NSEvent.enterExitEvent(
            with: .mouseEntered,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            trackingNumber: 0,
            userData: nil
        ))
        view.mouseEntered(with: event)
        view.mouseEntered(with: event)
        view.mouseExited(with: event)
        await Task.yield()
        await Task.yield()
        await Task.yield()
        #expect(changes == [true, false])
    }

    @Test
    func theAreaNeverTakesAClick() {
        #expect(HoverAreaView().hitTest(.zero) == nil)
    }
}
