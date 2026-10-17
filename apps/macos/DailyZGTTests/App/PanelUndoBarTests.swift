import AppKit
import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct PanelUndoBarTests {
    let clock = TestClock("2026-10-12T10:24:00")
    let recorder = ScheduleRecorder()

    private func makeState(_ store: AppStore) -> PanelState {
        PanelState(store: store, priorityFlow: PriorityFlow(store: store, schedule: recorder.schedule))
    }

    private func panelHeight(_ tab: PanelTab, store: AppStore, state: PanelState, named name: String) throws -> CGFloat {
        state.select(tab: tab)
        let view = PanelView().environment(store).environment(state)
        try Screenshot.writeHosted(view, named: name)
        return NSHostingView(rootView: view).fittingSize.height
    }

    @Test
    func theUndoBarShowsOnTheNotesTab() throws {
        let store = try makeStore(clock)
        let first = try store.addPriority(title: "Mandar el reporte", list: .today)
        try store.saveNote("Hablar con Ana sobre el brief.", scope: .day)
        let state = makeState(store)

        let without = try panelHeight(.notes, store: store, state: state, named: "notes-panel")
        state.priorityFlow.confirmDone(first.id)
        #expect(state.priorityFlow.undo?.title == "Mandar el reporte")
        let with = try panelHeight(.notes, store: store, state: state, named: "notes-undo-bar")

        #expect(with - without >= 30)
    }

    @Test
    func theUndoBarShowsOnThePrioritiesTabOnce() throws {
        let store = try makeStore(clock)
        let first = try store.addPriority(title: "Mandar el reporte", list: .today)
        try store.addPriority(title: "Otra", list: .today)
        let state = makeState(store)
        state.priorityFlow.confirmDone(first.id)
        #expect(state.priorityFlow.undo?.title == "Mandar el reporte")
        let doneOnly = try panelHeight(.priorities, store: store, state: state, named: "priorities-undo-bar")

        recorder.fire(0)
        #expect(state.priorityFlow.undo == nil)
        let afterTimer = try panelHeight(.priorities, store: store, state: state, named: "priorities-undo-bar-gone")

        #expect(doneOnly - afterTimer >= 30)
        #expect(doneOnly - afterTimer < 60)
    }

    @Test
    func theUndoBarEndsAfterFiveSecondsOnTheNotesTab() throws {
        let store = try makeStore(clock)
        let first = try store.addPriority(title: "Mandar el reporte", list: .today)
        let state = makeState(store)
        state.select(tab: .notes)
        state.priorityFlow.confirmDone(first.id)

        #expect(recorder.entries.map(\.delay) == [.milliseconds(5000)])
        let with = try panelHeight(.notes, store: store, state: state, named: "notes-undo-bar-timer")
        recorder.fire(0)
        let without = try panelHeight(.notes, store: store, state: state, named: "notes-undo-bar-timer-gone")
        #expect(with - without >= 30)
    }

    @Test
    func undoFromTheNotesTabRestoresThePriority() throws {
        let store = try makeStore(clock)
        let first = try store.addPriority(title: "Mandar el reporte", list: .today)
        let state = makeState(store)
        state.select(tab: .notes)
        state.priorityFlow.confirmDone(first.id)

        state.priorityFlow.undoDone()

        #expect(store.priority(id: first.id)?.isDone == false)
        #expect(state.priorityFlow.undo == nil)
    }
}
