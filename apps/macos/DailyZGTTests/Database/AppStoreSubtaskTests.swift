import Foundation
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct AppStoreSubtaskTests {
    let clock = TestClock()

    @Test
    func addKeepsTheOrderAndTouchesThePriority() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "Release", list: .today)
        clock.advance(minutes: 3)
        let first = try store.addSubtask(to: priority.id, title: "Write the notes")
        let second = try store.addSubtask(to: priority.id, title: "Tag the build")

        #expect(store.subtasks(of: priority.id) == [first, second])
        #expect(first.createdAt == clock.date)
        #expect(store.subtaskProgress(of: priority.id) == SubtaskProgress(done: 0, total: 2))
        #expect(store.priority(id: priority.id)?.updatedAt == clock.date)
        #expect(try store.events(of: priority.id).map(\.type) == [.created, .edited, .edited])
    }

    @Test
    func toggleMarksDoneThenOpen() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "Release", list: .today)
        let subtask = try store.addSubtask(to: priority.id, title: "Write the notes")
        try store.addSubtask(to: priority.id, title: "Tag the build")
        clock.advance(minutes: 7)

        let done = try store.toggleSubtask(subtask.id)
        #expect(done.doneAt == clock.date)
        #expect(store.subtaskProgress(of: priority.id) == SubtaskProgress(done: 1, total: 2))
        #expect(store.priority(id: priority.id)?.updatedAt == clock.date)
        #expect(try store.events(of: priority.id).map(\.type).last == .subtaskDone)

        let open = try store.toggleSubtask(subtask.id)
        #expect(open.doneAt == nil)
        #expect(store.subtaskProgress(of: priority.id) == SubtaskProgress(done: 0, total: 2))
        #expect(try store.events(of: priority.id).map(\.type) == [
            .created, .edited, .edited, .subtaskDone, .edited,
        ])
        #expect(store.openPriorities(in: .today).map(\.id) == [priority.id])
    }

    @Test
    func renameAndDelete() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "Release", list: .today)
        let first = try store.addSubtask(to: priority.id, title: "Write the notes")
        let second = try store.addSubtask(to: priority.id, title: "Tag the build")

        let renamed = try store.renameSubtask(first.id, title: "Write the release notes")
        #expect(renamed.title == "Write the release notes")
        #expect(store.subtasks(of: priority.id).map(\.title) == ["Write the release notes", "Tag the build"])

        try store.renameSubtask(first.id, title: "Write the release notes")
        #expect(try store.events(of: priority.id).count == 4)

        try store.deleteSubtask(first.id)
        #expect(store.subtasks(of: priority.id) == [second])
        #expect(store.subtaskProgress(of: priority.id) == SubtaskProgress(done: 0, total: 1))
        #expect(try store.events(of: priority.id).count == 5)
        #expect(throws: AppStoreError.subtaskNotFound(first.id)) {
            try store.toggleSubtask(first.id)
        }
    }

    @Test
    func progressOfAPriorityWithNoSubtasksIsZero() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "Release", list: .today)
        #expect(store.subtasks(of: priority.id).isEmpty)
        #expect(store.subtaskProgress(of: priority.id) == SubtaskProgress(done: 0, total: 0))
    }
}
