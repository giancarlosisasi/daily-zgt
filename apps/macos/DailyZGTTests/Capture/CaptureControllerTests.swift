import Foundation
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct CaptureControllerTests {
    let clock = TestClock("2026-10-12T10:24:00")
    let recorder = CaptureWindowRecorder()

    private func makeController(_ store: AppStore? = nil) throws -> (CaptureController, AppStore) {
        let store = try store ?? makeStore(clock)
        return (CaptureController(store: store, makeWindow: recorder.factory), store)
    }

    @Test
    func startsClosedAndCreatesNoWindow() throws {
        let (controller, _) = try makeController()
        #expect(!controller.isOpen)
        #expect(recorder.windows.isEmpty)
    }

    @Test
    func openShowsTheWindow() throws {
        let (controller, _) = try makeController()
        controller.open()
        #expect(controller.isOpen)
        #expect(recorder.windows.count == 1)
        #expect(recorder.windows[0].showCalls == 1)
    }

    @Test
    func openingTwiceShowsOnce() throws {
        let (controller, _) = try makeController()
        controller.open()
        controller.open()
        #expect(recorder.windows[0].showCalls == 1)
    }

    @Test
    func closeHidesTheWindow() throws {
        let (controller, _) = try makeController()
        controller.open()
        controller.close()
        #expect(!controller.isOpen)
        #expect(recorder.windows[0].hideCalls == 1)
    }

    @Test
    func closingAClosedWindowDoesNothing() throws {
        let (controller, _) = try makeController()
        controller.close()
        controller.open()
        controller.close()
        controller.close()
        #expect(recorder.windows[0].hideCalls == 1)
    }

    @Test
    func theWindowIsMadeOnceAndReused() throws {
        let (controller, _) = try makeController()
        controller.open()
        controller.close()
        controller.open()
        #expect(recorder.windows.count == 1)
        #expect(recorder.windows[0].showCalls == 2)
    }

    @Test
    func toggleOpensThenCloses() throws {
        let (controller, _) = try makeController()
        controller.toggle()
        #expect(controller.isOpen)
        controller.toggle()
        #expect(!controller.isOpen)
        controller.toggle()
        #expect(controller.isOpen)
    }

    @Test
    func escapeClosesWithNoAdd() throws {
        let (controller, store) = try makeController()
        controller.open()
        controller.model.draft.title = "No guardar"
        controller.cancel()
        #expect(!controller.isOpen)
        #expect(store.openCount(in: .today) == 0)
    }

    @Test
    func theShortcutAgainClosesWithNoAdd() throws {
        let (controller, store) = try makeController()
        let hotkey = FakeHotkeyService()
        defer { hotkey.removeStoredValue() }
        controller.attach(to: hotkey)
        hotkey.fire()
        controller.model.draft.title = "No guardar"
        hotkey.fire()
        #expect(!controller.isOpen)
        #expect(store.openCount(in: .today) == 0)
    }

    @Test
    func anEmptySubmitKeepsTheWindowOpen() throws {
        let (controller, store) = try makeController()
        controller.open()
        controller.submit()
        #expect(controller.isOpen)
        #expect(store.openCount(in: .today) == 0)
        #expect(recorder.windows[0].hideCalls == 0)
    }

    @Test
    func aSubmitWithATitleAddsAndCloses() throws {
        let (controller, store) = try makeController()
        controller.open()
        controller.model.draft.title = "Pagar la luz"
        controller.submit()
        #expect(!controller.isOpen)
        #expect(recorder.windows[0].hideCalls == 1)
        #expect(store.openPriorities(in: .today).map(\.title) == ["Pagar la luz"])
    }

    @Test
    func theLimitKeepsTheWindowOpenWithTheTextAndTheLine() throws {
        let store = try makeStore(clock)
        PanelState(store: store).setTodayLimit(true)
        for index in 0..<TodayLimit.maxOpen {
            try store.addPriority(title: "Open \(index)", list: .today)
        }
        let (controller, _) = try makeController(store)
        controller.open()
        controller.model.draft.title = "Una más"
        controller.submit()

        #expect(controller.isOpen)
        #expect(recorder.windows[0].hideCalls == 0)
        #expect(controller.model.draft.title == "Una más")
        #expect(controller.model.notice == "Hoy ya tiene 5 prioridades abiertas.")
        #expect(store.openCount(in: .today) == TodayLimit.maxOpen)
    }

    @Test
    func eachOpenStartsWithAnEmptyFieldAndNoLine() throws {
        let (controller, _) = try makeController()
        controller.open()
        controller.model.draft.title = "Texto viejo"
        controller.close()
        controller.open()
        #expect(controller.model.draft.title.isEmpty)
        #expect(controller.model.notice == nil)
    }

    @Test
    func aPriorityAddedFromTheWindowShowsInThePanelList() throws {
        let (controller, store) = try makeController()
        let state = PanelState(store: store)
        controller.open()
        controller.model.draft.title = "Pagar la luz"
        controller.submit()
        #expect(state.scope == .today)
        #expect(store.openPriorities(in: state.scope).map(\.title) == ["Pagar la luz"])
    }

    @Test
    func attachingStartsTheHotkeyServiceOnce() throws {
        let (controller, _) = try makeController()
        let hotkey = FakeHotkeyService()
        defer { hotkey.removeStoredValue() }
        controller.attach(to: hotkey)
        #expect(hotkey.startCalls == 1)
    }

    @Test
    func theHotkeyHandlerDoesNotKeepTheControllerAlive() throws {
        let hotkey = FakeHotkeyService()
        defer { hotkey.removeStoredValue() }
        weak var weakController: CaptureController?
        do {
            let (controller, _) = try makeController()
            weakController = controller
            controller.attach(to: hotkey)
        }
        #expect(weakController == nil)
        hotkey.fire()
    }
}
