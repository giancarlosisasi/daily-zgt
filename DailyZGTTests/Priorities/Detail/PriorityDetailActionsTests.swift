import Foundation
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct PriorityDetailActionsTests {
    let clock = TestClock("2026-10-12T10:24:00")

    private func setup() throws -> (AppStore, Priority, PriorityDetailActions) {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "Old title", level: .medium, list: .today)
        return (store, priority, PriorityDetailActions(store: store, id: priority.id))
    }

    private func events(_ store: AppStore, _ id: Priority.ID) throws -> [PriorityEventType] {
        try store.events(of: id).map(\.type)
    }

    @Test
    func aNewTitleWritesTheRowAndAnEditedEvent() throws {
        let (store, priority, actions) = try setup()
        clock.advance(minutes: 5)

        let shown = try actions.commitTitle("  New title ")
        #expect(shown == "New title")
        #expect(store.priority(id: priority.id)?.title == "New title")
        #expect(try values("SELECT title FROM priority", in: store.database, as: String.self) == ["New title"])
        #expect(try events(store, priority.id) == [.created, .edited])
        #expect(store.priority(id: priority.id)?.updatedAt == localDate("2026-10-12T10:29:00"))
    }

    @Test
    func anEmptyTitleKeepsTheOldTitleAndWritesNothing() throws {
        let (store, priority, actions) = try setup()

        #expect(try actions.commitTitle("   ") == "Old title")
        #expect(try actions.commitTitle("") == "Old title")
        #expect(store.priority(id: priority.id)?.title == "Old title")
        #expect(try events(store, priority.id) == [.created])
    }

    @Test
    func theSameTitleWritesNothing() throws {
        let (store, priority, actions) = try setup()

        #expect(try actions.commitTitle("Old title") == "Old title")
        #expect(try events(store, priority.id) == [.created])
    }

    @Test
    func aNewLevelWritesTheRowAndAnEditedEvent() throws {
        let (store, priority, actions) = try setup()

        try actions.setLevel(.high)
        #expect(store.priority(id: priority.id)?.level == .high)
        #expect(try values("SELECT level FROM priority", in: store.database, as: String.self) == ["high"])
        #expect(try events(store, priority.id) == [.created, .edited])
    }

    @Test
    func theSameLevelWritesNoEvent() throws {
        let (store, priority, actions) = try setup()

        try actions.setLevel(.medium)
        #expect(try events(store, priority.id) == [.created])
    }

    @Test
    func aDueCanBeSetChangedAndCleared() throws {
        let (store, priority, actions) = try setup()

        try actions.setDue(localDate("2026-10-12T16:00:00"))
        #expect(store.priority(id: priority.id)?.dueAt == localDate("2026-10-12T16:00:00"))
        #expect(try values("SELECT COUNT(*) FROM priority WHERE due_at IS NOT NULL", in: store.database, as: Int.self) == [1])

        try actions.setDue(localDate("2026-10-13T09:30:00"))
        #expect(store.priority(id: priority.id)?.dueAt == localDate("2026-10-13T09:30:00"))

        try actions.setDue(nil)
        #expect(store.priority(id: priority.id)?.dueAt == nil)
        #expect(try values("SELECT COUNT(*) FROM priority WHERE due_at IS NULL", in: store.database, as: Int.self) == [1])
        #expect(try events(store, priority.id) == [.created, .edited, .edited, .edited])
    }

    @Test
    func movingToTheOtherListWritesAMovedEventOnly() throws {
        let (store, priority, actions) = try setup()

        try actions.setList(.week)
        #expect(store.priority(id: priority.id)?.list == .week)
        #expect(try values("SELECT list FROM priority", in: store.database, as: String.self) == ["week"])
        #expect(try events(store, priority.id) == [.created, .moved])
        #expect(store.openPriorities(in: .today).isEmpty)
        #expect(store.openPriorities(in: .week).map(\.id) == [priority.id])
    }

    @Test
    func aChangeDoesNotTouchTheOtherFields() throws {
        let (store, priority, actions) = try setup()
        try actions.setDue(localDate("2026-10-12T16:00:00"))
        try actions.setLevel(.low)
        try actions.setList(.week)

        let saved = try #require(store.priority(id: priority.id))
        #expect(saved.title == "Old title")
        #expect(saved.dueAt == localDate("2026-10-12T16:00:00"))
        #expect(saved.level == .low)
        #expect(saved.list == .week)
        #expect(saved.createdAt == priority.createdAt)
    }

    @Test
    func aWriteOnAMissingPriorityThrows() throws {
        let store = try makeStore(clock)
        let actions = PriorityDetailActions(store: store, id: "missing")
        #expect(throws: AppStoreError.priorityNotFound("missing")) {
            try actions.setLevel(.high)
        }
        #expect(try actions.commitTitle("Anything") == "Anything")
    }
}
