import SwiftUI
import Testing
@testable import DailyZGT

@MainActor
final class ScheduleRecorder {
    struct Entry {
        let delay: Duration
        let action: @MainActor () -> Void
    }

    private(set) var entries: [Entry] = []

    var schedule: PrioritySchedule {
        { [self] delay, action in entries.append(Entry(delay: delay, action: action)) }
    }

    func fire(_ index: Int) {
        entries[index].action()
    }
}

@Suite
@MainActor
struct PriorityFlowTests {
    let clock = TestClock("2026-10-12T10:24:00")
    let recorder = ScheduleRecorder()

    private func makeFlow(_ store: AppStore) -> PriorityFlow {
        PriorityFlow(store: store, schedule: recorder.schedule)
    }

    private func eventTypes(_ store: AppStore, _ id: Priority.ID) throws -> [PriorityEventType] {
        try store.events(of: id).map(\.type)
    }

    @Test
    func theCheckboxOpensTheConfirmationAndCancelClosesIt() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)
        let first = try store.addPriority(title: "First", list: .today)

        #expect(flow.confirmingID == nil)
        flow.toggleConfirmation(for: first.id)
        #expect(flow.confirmingID == first.id)
        #expect(flow.isConfirming(first.id))

        flow.cancelConfirmation()
        #expect(flow.confirmingID == nil)
        #expect(store.priority(id: first.id)?.isDone == false)
        #expect(try eventTypes(store, first.id) == [.created])
    }

    @Test
    func aSecondClickOnTheCheckboxCancels() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)
        let first = try store.addPriority(title: "First", list: .today)

        flow.toggleConfirmation(for: first.id)
        flow.toggleConfirmation(for: first.id)
        #expect(flow.confirmingID == nil)
        #expect(flow.undo == nil)
    }

    @Test
    func onlyOneConfirmationIsOpenAtATime() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)
        let first = try store.addPriority(title: "First", list: .today)
        let second = try store.addPriority(title: "Second", list: .today)

        flow.toggleConfirmation(for: first.id)
        flow.toggleConfirmation(for: second.id)
        #expect(flow.confirmingID == second.id)
        #expect(!flow.isConfirming(first.id))
    }

    @Test
    func confirmingMarksDoneWritesTheEventAndShowsTheUndo() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)
        let first = try store.addPriority(title: "Send the report", list: .today)

        flow.toggleConfirmation(for: first.id)
        flow.confirmDone(first.id)

        #expect(flow.confirmingID == nil)
        #expect(store.priority(id: first.id)?.isDone == true)
        #expect(store.openPriorities(in: .today).isEmpty)
        #expect(try eventTypes(store, first.id) == [.created, .done])
        #expect(flow.undo?.priorityID == first.id)
        #expect(flow.undo?.title == "Send the report")
        #expect(!flow.writeFailed)
    }

    @Test
    func nothingIsMarkedDoneBeforeTheConfirmation() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)
        let first = try store.addPriority(title: "First", list: .today)

        flow.toggleConfirmation(for: first.id)
        #expect(store.priority(id: first.id)?.isDone == false)
        #expect(flow.undo == nil)
        #expect(recorder.entries.isEmpty)
    }

    @Test
    func theConfirmationTextCountsTheOpenSubtasks() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "With subtasks", list: .today)
        #expect(store.subtaskProgress(of: priority.id).openSubtasksLabel == nil)

        let first = try store.addSubtask(to: priority.id, title: "One")
        #expect(store.subtaskProgress(of: priority.id).openCount == 1)
        #expect(store.subtaskProgress(of: priority.id).openSubtasksLabel == "Queda 1 subtarea abierta.")

        try store.addSubtask(to: priority.id, title: "Two")
        try store.addSubtask(to: priority.id, title: "Three")
        try store.toggleSubtask(first.id)
        let progress = store.subtaskProgress(of: priority.id)
        #expect(progress.openCount == 2)
        #expect(progress.openSubtasksLabel == "Quedan 2 subtareas abiertas.")

        let all = SubtaskProgress(done: 3, total: 3)
        #expect(all.openCount == 0)
        #expect(all.openSubtasksLabel == nil)
    }

    @Test
    func undoRestoresThePriorityWritesTheEventAndHighlightsIt() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)
        let first = try store.addPriority(title: "First", list: .today)
        flow.confirmDone(first.id)

        flow.undoDone()

        #expect(flow.undo == nil)
        #expect(store.priority(id: first.id)?.isDone == false)
        #expect(store.openPriorities(in: .today).map(\.id) == [first.id])
        #expect(try eventTypes(store, first.id) == [.created, .done, .restored])
        #expect(flow.highlightedID == first.id)
    }

    @Test
    func theUndoBarEndsAfterFiveSeconds() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)
        let first = try store.addPriority(title: "First", list: .today)
        flow.confirmDone(first.id)

        #expect(recorder.entries.map(\.delay) == [.milliseconds(5000)])
        #expect(flow.undo != nil)
        recorder.fire(0)
        #expect(flow.undo == nil)
        #expect(store.priority(id: first.id)?.isDone == true)
    }

    @Test
    func aSecondDoneReplacesTheFirstUndo() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)
        let first = try store.addPriority(title: "First", list: .today)
        let second = try store.addPriority(title: "Second", list: .today)
        flow.confirmDone(first.id)
        flow.confirmDone(second.id)

        #expect(flow.undo?.priorityID == second.id)
        #expect(flow.undo?.title == "Second")

        recorder.fire(0)
        #expect(flow.undo?.priorityID == second.id)

        recorder.fire(1)
        #expect(flow.undo == nil)
    }

    @Test
    func undoAfterASecondDoneRestoresOnlyTheSecond() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)
        let first = try store.addPriority(title: "First", list: .today)
        let second = try store.addPriority(title: "Second", list: .today)
        flow.confirmDone(first.id)
        flow.confirmDone(second.id)

        flow.undoDone()

        #expect(store.priority(id: second.id)?.isDone == false)
        #expect(store.priority(id: first.id)?.isDone == true)
    }

    @Test
    func restoringFromTheDoneListClosesItsUndoBar() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)
        let first = try store.addPriority(title: "First", list: .today)
        flow.confirmDone(first.id)

        flow.restore(first.id)

        #expect(flow.undo == nil)
        #expect(store.priority(id: first.id)?.isDone == false)
    }

    @Test
    func aFailedWriteKeepsTheStateAndRaisesTheFlag() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)
        let first = try store.addPriority(title: "First", list: .today)
        flow.toggleConfirmation(for: first.id)
        try store.deletePriority(first.id)

        flow.confirmDone(first.id)

        #expect(flow.writeFailed)
        #expect(flow.undo == nil)
        #expect(flow.confirmingID == first.id)
    }

    @Test
    func theHighlightEndsAfter1400Milliseconds() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)

        flow.flash("a")
        #expect(flow.highlightedID == "a")
        #expect(recorder.entries.map(\.delay) == [.milliseconds(1400)])
        recorder.fire(0)
        #expect(flow.highlightedID == nil)
    }

    @Test
    func aNewHighlightIsNotClearedByTheOldTimer() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)

        flow.flash("a")
        flow.flash("b")
        recorder.fire(0)
        #expect(flow.highlightedID == "b")
        recorder.fire(1)
        #expect(flow.highlightedID == nil)
    }
}
