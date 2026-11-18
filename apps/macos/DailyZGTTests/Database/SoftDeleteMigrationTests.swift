import Foundation
import GRDB
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct SoftDeleteMigrationTests {
    static let rows = """
        INSERT INTO priority (id, title, note, level, list, due_at, done_at, position, created_at, updated_at) VALUES
            ('p1', 'Abierta', '', 'high', 'today', NULL, NULL, 1, '2026-11-16T09:00:00', '2026-11-16T09:00:00'),
            ('p2', 'Hecha', '', 'low', 'today', NULL, '2026-11-16T10:00:00', 2, '2026-11-16T09:00:00', '2026-11-16T10:00:00');
        INSERT INTO subtask (id, priority_id, title, done_at, position, created_at) VALUES
            ('s1', 'p1', 'Paso', NULL, 1, '2026-11-16T09:00:00');
        INSERT INTO note_item (id, body, created_at, updated_at) VALUES
            ('n1', 'Nota vieja', '2026-11-16T08:00:00', '2026-11-16T08:00:00');
        """

    private func migrated() throws -> DatabaseQueue {
        let database = try DatabaseQueue()
        try Schema.migrator.migrate(database, upTo: "004_add_note_item")
        try execute(Self.rows, in: database)
        try Schema.migrator.migrate(database)
        return database
    }

    @Test
    func theMigrationAddsTheColumnAndEachOldRowStaysLive() throws {
        let database = try migrated()
        let priorityColumns: [String] = try values("SELECT name FROM pragma_table_info('priority') ORDER BY cid", in: database)
        let noteColumns: [String] = try values("SELECT name FROM pragma_table_info('note_item') ORDER BY cid", in: database)
        #expect(priorityColumns.last == "deleted_at")
        #expect(noteColumns.last == "deleted_at")
        #expect(try values("SELECT COUNT(*) FROM priority WHERE deleted_at IS NULL", in: database) == [2])
        #expect(try values("SELECT COUNT(*) FROM note_item WHERE deleted_at IS NULL", in: database) == [1])
        #expect(try values("SELECT COUNT(*) FROM subtask", in: database) == [1])
        let migrations: [String] = try values("SELECT identifier FROM grdb_migrations ORDER BY identifier", in: database)
        #expect(migrations.last == "005_add_soft_delete")
        #expect(try values("PRAGMA integrity_check", in: database) == ["ok"])
    }

    @Test
    func theStoreReadsTheOldRowsAsLive() throws {
        let store = AppStore(database: try migrated(), now: { localDate("2026-11-16T12:00:00") })
        #expect(store.snapshot.open.map(\.id) == ["p1"])
        #expect(store.snapshot.done.map(\.id) == ["p2"])
        #expect(store.deletedPriorities.isEmpty)
        #expect(store.notes(in: .all).map(\.id) == ["n1"])
        #expect(store.deletedNotes.isEmpty)
        #expect(store.subtasks(of: "p1").map(\.title) == ["Paso"])
    }

    @Test
    func theMigrationRunsOnceWhenTheFileOpensAgain() throws {
        let folder = try temporaryFolder("soft-delete-migration-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "daily-zgt.sqlite")
        let old = try DatabaseQueue(path: url.path)
        try Schema.migrator.migrate(old, upTo: "004_add_note_item")
        try execute(Self.rows, in: old)
        try old.close()

        let first = try AppDatabase.onDisk(at: url)
        #expect(try values("SELECT COUNT(*) FROM priority", in: first) == [2])
        try first.close()
        let second = try AppDatabase.onDisk(at: url)
        #expect(try values("SELECT COUNT(*) FROM grdb_migrations", in: second) == [5])
        #expect(try values("SELECT COUNT(*) FROM priority WHERE deleted_at IS NULL", in: second) == [2])
        try second.close()
    }
}
