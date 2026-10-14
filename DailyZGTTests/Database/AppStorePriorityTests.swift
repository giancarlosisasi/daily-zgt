import Foundation
import GRDB
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct AppStorePriorityTests {
    let clock = TestClock()

    @Test
    func addWritesTheRowAndTheCreatedEvent() throws {
        let store = try makeStore(clock)
        let due = localDate("2026-10-12T16:00:00")
        let added = try store.addPriority(title: "Send the report", level: .high, list: .today, dueAt: due)

        #expect(added.title == "Send the report")
        #expect(added.level == .high)
        #expect(added.list == .today)
        #expect(added.dueAt == due)
        #expect(added.doneAt == nil)
        #expect(added.createdAt == clock.date)
        #expect(added.updatedAt == clock.date)
        #expect(store.priority(id: added.id) == added)
        #expect(store.openPriorities(in: .today) == [added])
        #expect(try store.events(of: added.id).map(\.type) == [.created])
        #expect(try store.events(of: added.id).map(\.at) == [clock.date])
    }

    @Test
    func addUsesMediumLevelAndNoDueByDefault() throws {
        let store = try makeStore(clock)
        let added = try store.addPriority(title: "Read", list: .week)
        #expect(added.level == .medium)
        #expect(added.dueAt == nil)
        #expect(added.note == "")
        #expect(store.openPriorities(in: .week) == [added])
        #expect(store.openPriorities(in: .today).isEmpty)
    }

    @Test
    func editWritesTheFieldsAndTheEditedEvent() throws {
        let store = try makeStore(clock)
        let added = try store.addPriority(title: "Draft", list: .today)
        clock.advance(minutes: 10)
        let due = localDate("2026-10-12T18:00:00")
        let edited = try store.editPriority(added.id) { priority in
            priority.title = "Final"
            priority.note = "Ask Ana"
            priority.level = .low
            priority.dueAt = due
        }

        #expect(edited.title == "Final")
        #expect(edited.note == "Ask Ana")
        #expect(edited.level == .low)
        #expect(edited.dueAt == due)
        #expect(edited.createdAt == added.createdAt)
        #expect(edited.updatedAt == clock.date)
        #expect(store.priority(id: added.id) == edited)
        #expect(try store.events(of: added.id).map(\.type) == [.created, .edited])
    }

    @Test
    func editWithNoChangeWritesNothing() throws {
        let store = try makeStore(clock)
        let added = try store.addPriority(title: "Draft", list: .today)
        clock.advance(minutes: 10)
        let same = try store.editPriority(added.id) { priority in
            priority.title = "Draft"
            priority.id = "other"
            priority.doneAt = Date()
            priority.position = 99
        }
        #expect(same == added)
        #expect(store.priority(id: added.id) == added)
        #expect(try store.events(of: added.id).map(\.type) == [.created])
    }

    @Test
    func moveChangesTheListAndWritesTheMovedEvent() throws {
        let store = try makeStore(clock)
        let added = try store.addPriority(title: "Plan the trip", list: .week)
        clock.advance(minutes: 5)
        let moved = try store.movePriority(added.id, to: .today)

        #expect(moved.list == .today)
        #expect(moved.updatedAt == clock.date)
        #expect(store.openPriorities(in: .week).isEmpty)
        #expect(store.openPriorities(in: .today) == [moved])
        #expect(try store.events(of: added.id).map(\.type) == [.created, .moved])

        try store.movePriority(added.id, to: .today)
        #expect(try store.events(of: added.id).map(\.type) == [.created, .moved])
    }

    @Test
    func editOfListAndTitleWritesMovedAndEdited() throws {
        let store = try makeStore(clock)
        let added = try store.addPriority(title: "Plan", list: .week)
        try store.editPriority(added.id) { priority in
            priority.list = .today
            priority.title = "Plan the trip"
        }
        #expect(try store.events(of: added.id).map(\.type) == [.created, .moved, .edited])
    }

    @Test
    func doneAndRestoreWriteTheirEvents() throws {
        let store = try makeStore(clock)
        let added = try store.addPriority(title: "Call the bank", list: .today)
        clock.advance(minutes: 30)
        let done = try store.markDone(added.id)

        #expect(done.doneAt == clock.date)
        #expect(done.updatedAt == clock.date)
        #expect(store.openPriorities(in: .today).isEmpty)
        #expect(store.donePriorities(in: .today) == [done])
        #expect(store.priority(id: added.id) == done)

        try store.markDone(added.id)
        #expect(try store.events(of: added.id).map(\.type) == [.created, .done])

        clock.advance(minutes: 1)
        let restored = try store.restorePriority(added.id)
        #expect(restored.doneAt == nil)
        #expect(restored.updatedAt == clock.date)
        #expect(store.openPriorities(in: .today) == [restored])
        #expect(store.donePriorities(in: .today).isEmpty)

        try store.restorePriority(added.id)
        #expect(try store.events(of: added.id).map(\.type) == [.created, .done, .restored])
    }

    @Test
    func deleteRemovesThePriorityWithItsSubtasksAndAlerts() throws {
        let store = try makeStore(clock)
        let kept = try store.addPriority(title: "Keep", list: .today)
        let removed = try store.addPriority(title: "Remove", list: .today)
        try store.addSubtask(to: removed.id, title: "One")
        try store.addSubtask(to: removed.id, title: "Two")
        try store.addSubtask(to: kept.id, title: "Stays")
        for (id, priorityID) in [("a1", removed.id), ("a2", removed.id), ("a3", kept.id)] {
            try insert(
                PriorityAlert(id: id, priorityID: priorityID, kind: .atDue, fireAt: clock.date, status: .scheduled),
                in: store.database
            )
        }

        let deleted = try store.deletePriority(removed.id)

        #expect(deleted.id == removed.id)
        #expect(store.priority(id: removed.id) == nil)
        #expect(store.subtasks(of: removed.id).isEmpty)
        #expect(store.openPriorities(in: .today).map(\.title) == ["Keep"])
        #expect(try values("SELECT title FROM subtask", in: store.database) == ["Stays"])
        #expect(try values("SELECT id FROM alert", in: store.database) == ["a3"])
    }

    @Test
    func aMissingPriorityThrows() throws {
        let store = try makeStore(clock)
        #expect(throws: AppStoreError.priorityNotFound("missing")) {
            try store.markDone("missing")
        }
        #expect(throws: AppStoreError.priorityNotFound("missing")) {
            try store.addSubtask(to: "missing", title: "One")
        }
    }

    @Test
    func openPrioritiesSortByLevelThenDueThenAge() throws {
        let store = try makeStore(clock)
        let rows: [(String, PriorityLevel, String?)] = [
            ("low, no due", .low, nil),
            ("high, 18:00", .high, "2026-10-12T18:00:00"),
            ("medium, 10:00, first", .medium, "2026-10-12T10:00:00"),
            ("high, no due", .high, nil),
            ("high, 16:00", .high, "2026-10-12T16:00:00"),
            ("medium, no due", .medium, nil),
            ("medium, 10:00, second", .medium, "2026-10-12T10:00:00"),
            ("low, 08:00", .low, "2026-10-12T08:00:00"),
            ("high, the day before", .high, "2026-10-11T23:00:00"),
        ]
        for (title, level, due) in rows {
            try store.addPriority(title: title, level: level, list: .today, dueAt: due.map(localDate))
        }
        try store.addPriority(title: "other list", level: .high, list: .week)

        #expect(store.openPriorities(in: .today).map(\.title) == [
            "high, the day before",
            "high, 16:00",
            "high, 18:00",
            "high, no due",
            "medium, 10:00, first",
            "medium, 10:00, second",
            "medium, no due",
            "low, 08:00",
            "low, no due",
        ])
        #expect(store.openPriorities(in: .week).map(\.title) == ["other list"])
    }

    @Test
    func donePrioritiesShowTheLatestFirst() throws {
        let store = try makeStore(clock)
        let first = try store.addPriority(title: "First", level: .low, list: .today)
        let second = try store.addPriority(title: "Second", level: .high, list: .today)
        let third = try store.addPriority(title: "Third", level: .medium, list: .today)
        try store.markDone(second.id)
        clock.advance(minutes: 5)
        try store.markDone(first.id)
        clock.advance(minutes: 5)
        try store.markDone(third.id)

        #expect(store.donePriorities(in: .today).map(\.title) == ["Third", "First", "Second"])
    }

    @Test
    func openCountIsPerList() throws {
        let store = try makeStore(clock)
        let done = try store.addPriority(title: "A", list: .today)
        try store.addPriority(title: "B", list: .today)
        try store.addPriority(title: "C", list: .today)
        try store.addPriority(title: "D", list: .week)
        try store.markDone(done.id)

        #expect(store.openCount(in: .today) == 2)
        #expect(store.openCount(in: .week) == 1)
    }

    @Test
    func datesAreLocalISO8601TextInTheFile() throws {
        let store = try makeStore(clock)
        let added = try store.addPriority(
            title: "Demo",
            list: .today,
            dueAt: localDate("2026-10-12T16:00:00").addingTimeInterval(0.4)
        )
        clock.advance(minutes: 90)
        try store.markDone(added.id)

        let database = store.database
        #expect(try values("SELECT due_at FROM priority", in: database) == ["2026-10-12T16:00:00"])
        #expect(try values("SELECT created_at FROM priority", in: database) == ["2026-10-12T09:00:00"])
        #expect(try values("SELECT done_at FROM priority", in: database) == ["2026-10-12T10:30:00"])
        #expect(try values("SELECT updated_at FROM priority", in: database) == ["2026-10-12T10:30:00"])
        #expect(try values("SELECT at FROM priority_event ORDER BY id", in: database) == [
            "2026-10-12T09:00:00",
            "2026-10-12T10:30:00",
        ])
        #expect(store.priority(id: added.id)?.dueAt == localDate("2026-10-12T16:00:00"))
    }
}
