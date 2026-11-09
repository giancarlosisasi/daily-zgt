import CoreGraphics
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct PriorityOrderTests {
    let clock = TestClock("2026-10-12T10:24:00")
    let recorder = ScheduleRecorder()

    @Test
    func movingDownPutsTheRowAboveTheGap() {
        #expect(PriorityOrder.moving("a", toGap: 3, in: ["a", "b", "c", "d"]) == ["b", "c", "a", "d"])
        #expect(PriorityOrder.moving("a", toGap: 4, in: ["a", "b", "c", "d"]) == ["b", "c", "d", "a"])
    }

    @Test
    func movingUpPutsTheRowAtTheGap() {
        #expect(PriorityOrder.moving("d", toGap: 1, in: ["a", "b", "c", "d"]) == ["a", "d", "b", "c"])
        #expect(PriorityOrder.moving("d", toGap: 0, in: ["a", "b", "c", "d"]) == ["d", "a", "b", "c"])
    }

    @Test
    func theGapsNextToTheRowOrAnUnknownRowKeepTheOrder() {
        let ids = ["a", "b", "c"]
        #expect(!PriorityOrder.changesOrder("b", gap: 1, in: ids))
        #expect(!PriorityOrder.changesOrder("b", gap: 2, in: ids))
        #expect(PriorityOrder.changesOrder("b", gap: 0, in: ids))
        #expect(PriorityOrder.changesOrder("b", gap: 3, in: ids))
        #expect(PriorityOrder.moving("x", toGap: 0, in: ids) == ids)
        #expect(PriorityOrder.moving("a", toGap: 9, in: ids) == ids)
    }

    @Test
    func theGapIsBeforeTheFirstRowWhoseMiddleIsBelowThePointer() {
        let midpoints: [CGFloat] = [18, 56, 94]
        #expect(PriorityOrder.gap(at: 0, midpoints: midpoints) == 0)
        #expect(PriorityOrder.gap(at: 20, midpoints: midpoints) == 1)
        #expect(PriorityOrder.gap(at: 55, midpoints: midpoints) == 1)
        #expect(PriorityOrder.gap(at: 200, midpoints: midpoints) == 3)
        #expect(PriorityOrder.gap(at: 10, midpoints: []) == 0)
    }

    @Test
    func aDragStartsOnlyAfterTheMouseMovesThreePoints() {
        #expect(!DragStartRule.hasMoved(from: .zero, to: CGPoint(x: 2, y: 2)))
        #expect(DragStartRule.hasMoved(from: .zero, to: CGPoint(x: 0, y: 3)))
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
    func aDragWritesTheNewOrderOnceOnDrop() throws {
        let store = try makeStore(clock)
        let flow = PriorityFlow(store: store, schedule: recorder.schedule)
        let first = try store.addPriority(title: "first", list: .today)
        try store.addPriority(title: "second", list: .today)
        try store.addPriority(title: "third", list: .today)

        flow.startDrag(first.id)
        #expect(flow.isDragging(first.id))
        flow.hover(gap: 2, in: .today)
        flow.hover(gap: 3, in: .today)
        #expect(flow.drag?.gap == 3)
        #expect(store.openPriorities(in: .today).map(\.title) == ["first", "second", "third"])

        flow.drop(in: .today)
        #expect(store.openPriorities(in: .today).map(\.title) == ["second", "third", "first"])
        #expect(flow.drag == nil)
        flow.endDrag()
        #expect(flow.drag == nil)
    }

    @Test
    func aGapNextToTheDraggedRowShowsNoLine() throws {
        let store = try makeStore(clock)
        let flow = PriorityFlow(store: store, schedule: recorder.schedule)
        try store.addPriority(title: "first", list: .today)
        let second = try store.addPriority(title: "second", list: .today)

        flow.startDrag(second.id)
        flow.hover(gap: 0, in: .today)
        #expect(flow.drag?.gap == 0)
        flow.hover(gap: 2, in: .today)
        #expect(flow.drag?.gap == nil)
        flow.hover(gap: 0, in: .today)
        flow.hover(gap: nil, in: .today)
        #expect(flow.drag?.gap == nil)
    }

    @Test
    func aCancelledDragOrADropWithNoGapKeepsTheOrder() throws {
        let store = try makeStore(clock)
        let flow = PriorityFlow(store: store, schedule: recorder.schedule)
        let first = try store.addPriority(title: "first", list: .today)
        try store.addPriority(title: "second", list: .today)

        flow.startDrag(first.id)
        flow.hover(gap: 2, in: .today)
        flow.endDrag()
        #expect(flow.drag == nil)
        flow.drop(in: .today)

        flow.startDrag(first.id)
        flow.drop(in: .today)
        #expect(store.openPriorities(in: .today).map(\.title) == ["first", "second"])
    }

    @Test
    func hoveringWithNoDragDoesNothing() throws {
        let store = try makeStore(clock)
        let flow = PriorityFlow(store: store, schedule: recorder.schedule)
        try store.addPriority(title: "first", list: .today)

        flow.hover(gap: 0, in: .today)
        #expect(flow.drag == nil)
    }
}
