import Foundation
import GRDB
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct DiskDatabaseTests {
    @Test
    func aFileOnDiskKeepsItsRowsAfterCloseAndOpen() throws {
        let url = try temporaryFolder("persistence").appending(path: "daily-zgt.sqlite")
        let clock = TestClock()

        let first = try AppDatabase.onDisk(at: url)
        try writeSample(in: first, clock: clock)
        try first.close()

        let second = try AppDatabase.onDisk(at: url)
        let store = AppStore(database: second, now: { clock.date })
        let priority = try #require(store.openPriorities(in: .today).first)
        #expect(priority.title == "Send the report")
        #expect(priority.level == .high)
        #expect(priority.dueAt == localDate("2026-10-12T16:00:00"))
        #expect(store.subtasks(of: priority.id).map(\.title) == ["Check the numbers"])
        #expect(store.noteBody(.day) == "Call Ana")
        #expect(store.value(for: AppStateKey(name: "open_tab", defaultValue: "priorities")) == "notes")
        #expect(try store.events(of: priority.id).map(\.type) == [.created, .edited])
    }

    @Test
    func aFileOnDiskUsesWALAndForeignKeys() throws {
        let folder = try temporaryFolder("pragmas-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let database = try AppDatabase.onDisk(at: folder.appending(path: "nested/daily-zgt.sqlite"))

        #expect(try values("PRAGMA journal_mode", in: database) == ["wal"])
        #expect(try values("PRAGMA foreign_keys", in: database) == [1])
        #expect(FileManager.default.fileExists(atPath: database.path + "-wal"))
    }

    private func writeSample(in database: DatabaseQueue, clock: TestClock) throws {
        let store = AppStore(database: database, now: { clock.date })
        let priority = try store.addPriority(
            title: "Send the report",
            level: .high,
            list: .today,
            dueAt: localDate("2026-10-12T16:00:00")
        )
        try store.addSubtask(to: priority.id, title: "Check the numbers")
        try store.saveNote("Call Ana", scope: .day)
        try store.setValue("notes", for: AppStateKey(name: "open_tab", defaultValue: "priorities"))
    }
}
