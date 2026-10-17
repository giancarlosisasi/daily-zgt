import AppKit
import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct PanelUndoBarIdentityTests {
    let clock = TestClock("2026-10-12T10:24:00")
    let recorder = ScheduleRecorder()

    private func makeState(_ store: AppStore) -> PanelState {
        PanelState(store: store, priorityFlow: PriorityFlow(store: store, schedule: recorder.schedule))
    }

    @Test
    func bothTabsHoldTheSameSlotsOnce() {
        for tab in PanelTab.allCases {
            let order = PanelContentSlot.order(for: tab)
            #expect(order.count == PanelContentSlot.allCases.count)
            #expect(Set(order) == Set(PanelContentSlot.allCases))
        }
    }

    @Test
    func theUndoBarChangesPositionAndKeepsItsSlot() {
        let priorities = PanelContentSlot.order(for: .priorities)
        let notes = PanelContentSlot.order(for: .notes)
        #expect(priorities == [.main, .undoBar])
        #expect(notes == [.undoBar, .main])
        #expect(priorities.firstIndex(of: .undoBar) != notes.firstIndex(of: .undoBar))
    }

    @Test
    func theUndoStaysTheSameAcrossTabSwitches() throws {
        let store = try makeStore(clock)
        let first = try store.addPriority(title: "Mandar el reporte", list: .today)
        let state = makeState(store)
        state.priorityFlow.confirmDone(first.id)
        let token = try #require(state.priorityFlow.undo?.token)

        state.select(tab: .notes)
        #expect(state.priorityFlow.undo?.token == token)
        state.select(tab: .priorities)
        #expect(state.priorityFlow.undo?.token == token)
        #expect(recorder.entries.count == 1)
    }

    @Test
    func theBarHasTheSameHeightOnBothTabs() throws {
        let store = try makeStore(clock)
        let first = try store.addPriority(title: "Mandar el reporte", list: .today)
        try store.addPriority(title: "Otra", list: .today)
        try store.saveNote("Hablar con Ana sobre el brief.", scope: .day)
        let state = makeState(store)

        func height(_ tab: PanelTab, named name: String? = nil) throws -> CGFloat {
            state.select(tab: tab)
            let view = PanelView().environment(store).environment(state)
            if let name {
                try Screenshot.writeHosted(view, named: name)
            }
            return NSHostingView(rootView: view).fittingSize.height
        }

        let prioritiesWithout = try height(.priorities)
        let notesWithout = try height(.notes)
        state.priorityFlow.confirmDone(first.id)
        let prioritiesBar = try height(.priorities, named: "undo-bar-tab-priorities")
        let notesBar = try height(.notes, named: "undo-bar-tab-notes")

        let onPriorities = prioritiesBar - prioritiesWithout
        let onNotes = notesBar - notesWithout
        #expect(onNotes >= 30)
        #expect(onPriorities > 0)
        #expect(state.priorityFlow.undo != nil)
    }
}
