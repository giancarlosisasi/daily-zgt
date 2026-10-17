import Foundation
import GRDB
import Testing
@testable import DailyZGT

enum FirstSchema {
    static let name = "001_create_tables"
    static let tables = ["priority", "subtask", "note", "alert", "priority_event", "app_state"]

    static let rows = """
        INSERT INTO priority (id, title, note, level, list, due_at, done_at, position, created_at, updated_at) VALUES
            ('p1', 'Meditar', 'Diez minutos.', 'high', 'today', '2026-10-12T08:00:00', NULL, 1,
             '2026-10-10T07:00:00', '2026-10-12T07:30:00'),
            ('p2', 'Leer', '', 'low', 'week', NULL, '2026-10-11T21:15:00', 2,
             '2026-10-09T09:00:00', '2026-10-11T21:15:00'),
            ('p3', 'Sin nada', '', 'medium', 'today', NULL, NULL, 3,
             '2026-10-12T09:00:00', '2026-10-12T09:00:00');
        INSERT INTO subtask (id, priority_id, title, done_at, position, created_at) VALUES
            ('s1', 'p1', 'Respirar', '2026-10-12T07:30:00', 1, '2026-10-10T07:00:00'),
            ('s2', 'p1', 'Estirar', NULL, 2, '2026-10-10T07:01:00'),
            ('s3', 'p2', 'Un capítulo', NULL, 1, '2026-10-09T09:00:00');
        INSERT INTO alert (id, priority_id, kind, fire_at, status) VALUES
            ('a1', 'p1', 'before_30m', '2026-10-12T07:30:00', 'delivered'),
            ('a2', 'p1', 'at_due', '2026-10-12T08:00:00', 'scheduled'),
            ('a3', 'p2', 'snooze', '2026-10-11T20:00:00', 'cancelled');
        INSERT INTO priority_event (priority_id, at, type) VALUES
            ('p1', '2026-10-10T07:00:00', 'created'),
            ('p1', '2026-10-12T07:30:00', 'subtask_done'),
            ('p2', '2026-10-09T09:00:00', 'created'),
            ('p2', '2026-10-10T09:00:00', 'moved'),
            ('p2', '2026-10-11T21:15:00', 'done'),
            ('p3', '2026-10-12T09:00:00', 'created'),
            ('gone', '2026-10-01T09:00:00', 'created');
        INSERT INTO note (scope, period, body, updated_at) VALUES
            ('day', '2026-10-12', 'Llamar a Ana', '2026-10-12T09:00:00'),
            ('week', '2026-W42', 'Cerrar el brief', '2026-10-12T09:05:00');
        INSERT INTO app_state (key, value) VALUES ('open_tab', '"notes"'), ('done_open', 'true');
        """

    static func fill(_ database: DatabaseQueue) throws {
        try Schema.migrator.migrate(database, upTo: name)
        try execute(rows, in: database)
    }

    static func contents(of database: DatabaseQueue) throws -> [String: [[DatabaseValue]]] {
        let queries = [
            "priority": """
                SELECT id, title, note, level, list, due_at, done_at, position, created_at, updated_at
                FROM priority ORDER BY id
                """,
            "subtask": "SELECT * FROM subtask ORDER BY id",
            "note": "SELECT * FROM note ORDER BY scope, period",
            "alert": "SELECT * FROM alert ORDER BY id",
            "priority_event": "SELECT * FROM priority_event ORDER BY id",
            "app_state": "SELECT * FROM app_state ORDER BY key",
        ]
        return try database.read { connection in
            try queries.mapValues { sql in
                try Row.fetchAll(connection, sql: sql).map { Array($0.databaseValues) }
            }
        }
    }
}

@Suite
@MainActor
struct RepeatMigrationTests {
    private func migratedFromFirstSchema() throws -> (DatabaseQueue, [String: [[DatabaseValue]]]) {
        let database = try DatabaseQueue()
        try FirstSchema.fill(database)
        let before = try FirstSchema.contents(of: database)
        try Schema.migrator.migrate(database)
        return (database, before)
    }

    @Test
    func theFirstSchemaHasNoRepeatColumn() throws {
        let database = try DatabaseQueue()
        try FirstSchema.fill(database)
        let names: [String] = try values("SELECT name FROM pragma_table_info('priority')", in: database)
        #expect(!names.contains("repeat_rule"))
        #expect(!names.contains("repeat_series_id"))
        #expect(try values("SELECT identifier FROM grdb_migrations", in: database) == [FirstSchema.name])
    }

    @Test
    func theMigrationKeepsEachRowOfEachTable() throws {
        let (database, before) = try migratedFromFirstSchema()
        let after = try FirstSchema.contents(of: database)

        #expect(before["priority"]?.count == 3)
        #expect(before["subtask"]?.count == 3)
        #expect(before["alert"]?.count == 3)
        #expect(before["priority_event"]?.count == 7)
        #expect(before["note"]?.count == 2)
        #expect(before["app_state"]?.count == 2)
        for table in FirstSchema.tables {
            #expect(after[table] == before[table], "\(table)")
        }
        #expect(try values("SELECT identifier FROM grdb_migrations ORDER BY identifier", in: database) == [
            FirstSchema.name,
            "002_add_repeat_to_priority",
        ])
    }

    @Test
    func theOldRowsGetTheRuleNoneAndNoSeries() throws {
        let (database, _) = try migratedFromFirstSchema()
        #expect(try values("SELECT repeat_rule FROM priority ORDER BY id", in: database) == ["none", "none", "none"])
        #expect(try values("SELECT COUNT(*) FROM priority WHERE repeat_series_id IS NULL", in: database) == [3])

        let priorities = try database.read { try Priority.fetchAll($0, sql: "SELECT * FROM priority ORDER BY id") }
        #expect(priorities.map(\.repeatRule) == [.none, .none, .none])
        #expect(priorities.map(\.seriesID) == ["p1", "p2", "p3"])
        #expect(priorities.first?.dueAt == localDate("2026-10-12T08:00:00"))
    }

    @Test
    func theMigrationKeepsTheForeignKeysAndTheIndexes() throws {
        let (database, _) = try migratedFromFirstSchema()
        let broken = try database.read { try Row.fetchAll($0, sql: "PRAGMA foreign_key_check").count }
        #expect(broken == 0)
        #expect(try values("PRAGMA integrity_check", in: database) == ["ok"])
        #expect(try values("PRAGMA foreign_keys", in: database) == [1])
        #expect(try values(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'priority' AND name NOT LIKE 'sqlite_%'",
            in: database
        ) == ["priority_on_list_done_at"])

        let error = #expect(throws: DatabaseError.self) {
            try execute(
                """
                INSERT INTO subtask (id, priority_id, title, position, created_at)
                VALUES ('s9', 'missing', 'Title', 1, '2026-10-12T09:00:00')
                """,
                in: database
            )
        }
        #expect(error?.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY)

        try execute("DELETE FROM priority WHERE id = 'p1'", in: database)
        #expect(try values("SELECT id FROM subtask ORDER BY id", in: database) == ["s3"])
        #expect(try values("SELECT id FROM alert ORDER BY id", in: database) == ["a3"])
        #expect(try values("SELECT COUNT(*) FROM priority_event WHERE priority_id = 'p1'", in: database) == [2])
    }

    @Test
    func theRuleAcceptsOnlyItsTwoValues() throws {
        let (database, _) = try migratedFromFirstSchema()
        try execute("UPDATE priority SET repeat_rule = 'daily', repeat_series_id = 'p2' WHERE id = 'p1'", in: database)
        #expect(try values("SELECT repeat_rule FROM priority WHERE id = 'p1'", in: database) == ["daily"])

        for sql in [
            "UPDATE priority SET repeat_rule = 'weekly' WHERE id = 'p1'",
            "UPDATE priority SET repeat_rule = NULL WHERE id = 'p1'",
        ] {
            let error = #expect(throws: DatabaseError.self) {
                try execute(sql, in: database)
            }
            #expect(error?.resultCode == .SQLITE_CONSTRAINT)
        }
        #expect(RepeatRule.allCases.map(\.rawValue) == ["none", "daily"])
    }

    @Test
    func aNewDatabaseHasTheSameColumnsAsAMigratedOne() throws {
        let (migrated, _) = try migratedFromFirstSchema()
        let fresh = try AppDatabase.inMemory()
        let columns = "SELECT name || ':' || type || ':' || \"notnull\" FROM pragma_table_info('priority') ORDER BY cid"
        #expect(try values(columns, in: migrated, as: String.self) == values(columns, in: fresh, as: String.self))
    }

    @Test
    func aFileWithTheFirstSchemaMigratesWhenTheAppOpensIt() throws {
        let folder = try temporaryFolder("repeat-migration-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "daily-zgt.sqlite")

        var configuration = Configuration()
        configuration.journalMode = .wal
        configuration.foreignKeysEnabled = true
        let old = try DatabaseQueue(path: url.path, configuration: configuration)
        try FirstSchema.fill(old)
        let before = try FirstSchema.contents(of: old)
        try old.close()

        let opened = try AppDatabase.onDisk(at: url)
        #expect(try FirstSchema.contents(of: opened) == before)
        try expectTheStoreReadsTheOldRows(in: opened)
        try opened.close()

        let again = try AppDatabase.onDisk(at: url)
        #expect(try FirstSchema.contents(of: again) == before)
        #expect(try values("SELECT COUNT(*) FROM grdb_migrations", in: again) == [2])
    }

    private func expectTheStoreReadsTheOldRows(in database: DatabaseQueue) throws {
        let store = AppStore(database: database, now: { localDate("2026-10-12T10:00:00") })
        #expect(store.openPriorities(in: .today).map(\.title) == ["Meditar", "Sin nada"])
        #expect(store.donePriorities(in: .week).map(\.repeatRule) == [.none])
        #expect(store.subtasks(of: "p1").map(\.title) == ["Respirar", "Estirar"])
        #expect(try store.alerts().map(\.id) == ["a3", "a1", "a2"])
    }
}
