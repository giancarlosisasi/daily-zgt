import Testing
@testable import DailyZGT

@Suite
@MainActor
struct PriorityOrderTests {
    let clock = TestClock("2026-10-12T10:24:00")
    let recorder = ScheduleRecorder()

    @Test
    func movingDownPutsTheRowInTheTargetSlot() {
        #expect(PriorityOrder.moving("a", to: "c", in: ["a", "b", "c", "d"]) == ["b", "c", "a", "d"])
    }

    @Test
    func movingUpPutsTheRowInTheTargetSlot() {
        #expect(PriorityOrder.moving("d", to: "b", in: ["a", "b", "c", "d"]) == ["a", "d", "b", "c"])
    }

    @Test
    func theSameOrAnUnknownRowKeepsTheOrder() {
        #expect(PriorityOrder.moving("a", to: "a", in: ["a", "b"]) == ["a", "b"])
        #expect(PriorityOrder.moving("x", to: "a", in: ["a", "b"]) == ["a", "b"])
        #expect(PriorityOrder.moving("a", to: "x", in: ["a", "b"]) == ["a", "b"])
    }

    @Test
    func aNewPriorityGoesToTheEndWhateverItsLevel() throws {
        let store = try makeStore(clock)
        try store.addPriority(title: "low", level: .low, list: .today)
        try store.addPriority(title: "high", level: .high, list: .today, dueAt: localDate("2026-10-12T11:00:00"))
        #expect(store.openPriorities(in: .today).map(\.title) == ["low", "high"])
    }

    @Test
    func reorderingOneListKeepsTheOtherList() throws {
        let store = try makeStore(clock)
        let first = try store.addPriority(title: "first", list: .today)
        let week = try store.addPriority(title: "week", list: .week)
        let second = try store.addPriority(title: "second", list: .today)
        let third = try store.addPriority(title: "third", list: .today)

        try store.reorderPriorities([third.id, first.id, second.id])
        #expect(store.openPriorities(in: .today).map(\.title) == ["third", "first", "second"])
        #expect(store.openPriorities(in: .week).map(\.id) == [week.id])
        #expect(store.priority(id: week.id)?.position == week.position)
        #expect(try store.events(of: first.id).map(\.type) == [.created])
    }

    @Test
    func adoptingTheManualOrderKeepsTheOldLevelAndDueOrderOnce() throws {
        let store = try makeStore(clock)
        try store.addPriority(title: "low no due", level: .low, list: .today)
        try store.addPriority(title: "medium no due", level: .medium, list: .today)
        try store.addPriority(title: "high late", level: .high, list: .today, dueAt: localDate("2026-10-12T18:00:00"))
        try store.addPriority(title: "high no due", level: .high, list: .today)
        try store.addPriority(title: "high early", level: .high, list: .today, dueAt: localDate("2026-10-12T12:00:00"))

        try store.adoptManualOrder()
        let adopted = store.openPriorities(in: .today)
        #expect(adopted.map(\.title) == ["high early", "high late", "high no due", "medium no due", "low no due"])

        try store.reorderPriorities(adopted.reversed().map(\.id))
        try store.adoptManualOrder()
        #expect(store.openPriorities(in: .today).map(\.title) == adopted.reversed().map(\.title))
    }

    @Test
    func draggingOverAnotherRowMovesTheDraggedRow() throws {
        let store = try makeStore(clock)
        let flow = PriorityFlow(store: store, schedule: recorder.schedule)
        let first = try store.addPriority(title: "first", list: .today)
        try store.addPriority(title: "second", list: .today)
        let third = try store.addPriority(title: "third", list: .today)

        flow.startDrag(first.id)
        flow.dragEntered(third.id, in: .today)
        #expect(store.openPriorities(in: .today).map(\.title) == ["second", "third", "first"])
        flow.endDrag()
        #expect(flow.draggingID == nil)
    }

    @Test
    func enteringARowWithNoDragDoesNothing() throws {
        let store = try makeStore(clock)
        let flow = PriorityFlow(store: store, schedule: recorder.schedule)
        let first = try store.addPriority(title: "first", list: .today)
        try store.addPriority(title: "second", list: .today)

        flow.dragEntered(first.id, in: .today)
        #expect(store.openPriorities(in: .today).map(\.title) == ["first", "second"])
    }
}
