import Foundation
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct PriorityLeaveTests {
    let clock = TestClock("2026-10-12T10:24:00")
    let recorder = ScheduleRecorder()
    let leave = Duration.tecla(Theme.Motion.slow)

    private func makeFlow(_ store: AppStore) -> PriorityFlow {
        PriorityFlow(store: store, schedule: recorder.schedule)
    }

    @Test
    func aRowStaysOpenForTheLeaveTimeAndThenIsMarkedDone() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)
        let first = try store.addPriority(title: "First", list: .today)
        flow.toggleConfirmation(for: first.id)

        flow.confirmDone(first.id, leaving: leave)

        #expect(flow.isLeaving(first.id))
        #expect(store.priority(id: first.id)?.isDone == false)
        #expect(flow.undo == nil)
        #expect(recorder.entries.count == 1)
        #expect(recorder.entries[0].delay == leave)
        #expect(leave == .milliseconds(320))

        recorder.fire(0)

        #expect(!flow.isLeaving(first.id))
        #expect(store.priority(id: first.id)?.isDone == true)
        #expect(flow.confirmingID == nil)
        #expect(flow.undo?.priorityID == first.id)
        #expect(!flow.writeFailed)
    }

    @Test
    func aSecondHechaWhileTheRowLeavesDoesNothing() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)
        let first = try store.addPriority(title: "First", list: .today)
        flow.toggleConfirmation(for: first.id)

        flow.confirmDone(first.id, leaving: leave)
        flow.confirmDone(first.id, leaving: leave)
        flow.confirmDone(first.id)

        #expect(recorder.entries.count == 1)
        #expect(store.priority(id: first.id)?.isDone == false)

        recorder.fire(0)

        #expect(try store.events(of: first.id).map(\.type) == [.created, .done])
        #expect(recorder.entries.count == 2)
    }

    @Test
    func theCheckboxAndCancelDoNothingWhileTheRowLeaves() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)
        let first = try store.addPriority(title: "First", list: .today)
        flow.toggleConfirmation(for: first.id)
        flow.confirmDone(first.id, leaving: leave)

        flow.toggleConfirmation(for: first.id)
        flow.cancelConfirmation()

        #expect(flow.confirmingID == first.id)
        #expect(flow.isLeaving(first.id))
    }

    @Test
    func deshacerDuringTheLeaveRestoresTheEarlierRowAndTheLeavingRowStillGoes() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)
        let first = try store.addPriority(title: "First", list: .today)
        let second = try store.addPriority(title: "Second", list: .today)
        flow.confirmDone(first.id)
        #expect(flow.undo?.priorityID == first.id)

        flow.toggleConfirmation(for: second.id)
        let leaveIndex = recorder.entries.count
        flow.confirmDone(second.id, leaving: leave)
        flow.undoDone()

        #expect(store.priority(id: first.id)?.isDone == false)
        #expect(flow.undo == nil)
        #expect(flow.isLeaving(second.id))
        #expect(store.priority(id: second.id)?.isDone == false)

        recorder.fire(leaveIndex)

        #expect(store.priority(id: second.id)?.isDone == true)
        #expect(store.priority(id: first.id)?.isDone == false)
        #expect(flow.undo?.priorityID == second.id)
        #expect(flow.undo?.title == "Second")
        #expect(!flow.isLeaving(second.id))
    }

    @Test
    func deshacerAfterTheLeaveRestoresTheRowThatLeft() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)
        let first = try store.addPriority(title: "First", list: .today)
        flow.toggleConfirmation(for: first.id)
        flow.confirmDone(first.id, leaving: leave)
        recorder.fire(0)

        flow.undoDone()

        #expect(store.priority(id: first.id)?.isDone == false)
        #expect(flow.undo == nil)
        #expect(flow.highlightedID == first.id)
        #expect(try store.events(of: first.id).map(\.type) == [.created, .done, .restored])
    }

    @Test
    func removingARowWhileItLeavesStopsTheDoneWrite() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)
        let first = try store.addPriority(title: "First", list: .today)
        flow.toggleConfirmation(for: first.id)
        flow.confirmDone(first.id, leaving: leave)

        flow.delete(first.id)
        recorder.fire(0)

        #expect(store.priority(id: first.id) == nil)
        #expect(flow.undo == nil)
        #expect(!flow.writeFailed)
        #expect(!flow.isLeaving(first.id))
    }

    @Test
    func aRowRemovedByAnotherPathWhileItLeavesDoesNotFailTheWrite() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)
        let first = try store.addPriority(title: "First", list: .today)
        flow.confirmDone(first.id, leaving: leave)

        try store.deletePriority(first.id)
        recorder.fire(0)

        #expect(flow.undo == nil)
        #expect(!flow.writeFailed)
        #expect(!flow.isLeaving(first.id))
    }

    @Test
    func theConfirmationOfAnotherRowSurvivesTheEndOfTheLeave() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)
        let first = try store.addPriority(title: "First", list: .today)
        let second = try store.addPriority(title: "Second", list: .today)
        flow.toggleConfirmation(for: first.id)
        flow.confirmDone(first.id, leaving: leave)
        flow.toggleConfirmation(for: second.id)

        recorder.fire(0)

        #expect(flow.confirmingID == second.id)
        #expect(store.priority(id: first.id)?.isDone == true)
    }
}
