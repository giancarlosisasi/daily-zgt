import Foundation
import GRDB
import Testing
@testable import DailyZGT

@Suite
struct SchemaTests {
    static let validPriority = """
        INSERT INTO priority (id, title, level, list, position, created_at, updated_at)
        VALUES ('p1', 'Title', 'high', 'today', 1, '2026-10-12T09:00:00', '2026-10-12T09:00:00')
        """

    @Test
    func createsTheSixTables() throws {
        let database = try AppDatabase.inMemory()
        let tables: [String] = try values(
            """
            SELECT name FROM sqlite_master
            WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name <> 'grdb_migrations'
            ORDER BY name
            """,
            in: database
        )
        #expect(tables == ["alert", "app_state", "note", "priority", "priority_event", "subtask"])
    }

    @Test(arguments: [
        (
            "priority",
            [
                "id", "title", "note", "level", "list", "due_at", "done_at", "position", "created_at", "updated_at",
                "repeat_rule", "repeat_series_id",
            ]
        ),
        ("subtask", ["id", "priority_id", "title", "done_at", "position", "created_at"]),
        ("note", ["scope", "period", "body", "updated_at"]),
        ("alert", ["id", "priority_id", "kind", "fire_at", "status"]),
        ("priority_event", ["id", "priority_id", "at", "type"]),
        ("app_state", ["key", "value"]),
    ])
    func tableHasThePlannedColumns(table: String, columns: [String]) throws {
        let database = try AppDatabase.inMemory()
        let names: [String] = try values(
            "SELECT name FROM pragma_table_info('\(table)') ORDER BY cid",
            in: database
        )
        #expect(names == columns)
    }

    @Test(arguments: [
        """
        INSERT INTO priority (id, title, level, list, position, created_at, updated_at)
        VALUES ('p2', 'Title', 'urgent', 'today', 1, '2026-10-12T09:00:00', '2026-10-12T09:00:00')
        """,
        """
        INSERT INTO priority (id, title, level, list, position, created_at, updated_at)
        VALUES ('p2', 'Title', 'high', 'month', 1, '2026-10-12T09:00:00', '2026-10-12T09:00:00')
        """,
        "INSERT INTO note (scope, period, body, updated_at) VALUES ('month', '2026-10', '', '2026-10-12T09:00:00')",
        """
        INSERT INTO alert (id, priority_id, kind, fire_at, status)
        VALUES ('a1', 'p1', 'later', '2026-10-12T15:30:00', 'scheduled')
        """,
        """
        INSERT INTO alert (id, priority_id, kind, fire_at, status)
        VALUES ('a1', 'p1', 'at_due', '2026-10-12T15:30:00', 'lost')
        """,
        "INSERT INTO priority_event (priority_id, at, type) VALUES ('p1', '2026-10-12T09:00:00', 'deleted')",
    ])
    func rejectsAValueOutsideItsSet(sql: String) throws {
        let database = try AppDatabase.inMemory()
        try execute(Self.validPriority, in: database)
        let error = #expect(throws: DatabaseError.self) {
            try execute(sql, in: database)
        }
        #expect(error?.extendedResultCode == .SQLITE_CONSTRAINT_CHECK)
    }

    @Test
    func acceptsEachValueOfTheSets() throws {
        let database = try AppDatabase.inMemory()
        let at = localDate("2026-10-12T09:00:00")
        try execute(Self.validPriority, in: database)
        for kind in AlertKind.allCases {
            for status in AlertStatus.allCases {
                try insert(
                    PriorityAlert(
                        id: "\(kind.rawValue)-\(status.rawValue)",
                        priorityID: "p1",
                        kind: kind,
                        fireAt: at,
                        status: status
                    ),
                    in: database
                )
            }
        }
        for type in PriorityEventType.allCases {
            try insert(PriorityEvent(id: nil, priorityID: "p1", at: at, type: type), in: database)
        }
        let kinds: [String] = try values("SELECT DISTINCT kind FROM alert ORDER BY kind", in: database)
        let statuses: [String] = try values("SELECT DISTINCT status FROM alert ORDER BY status", in: database)
        let types: [String] = try values("SELECT type FROM priority_event ORDER BY id", in: database)
        #expect(kinds == ["at_due", "before_30m", "snooze"])
        #expect(statuses == ["cancelled", "delivered", "scheduled", "snoozed"])
        #expect(types == ["created", "edited", "moved", "done", "restored", "subtask_done"])
    }

    @Test
    func noteIsUniqueByScopeAndPeriod() throws {
        let database = try AppDatabase.inMemory()
        let insertNote = """
            INSERT INTO note (scope, period, body, updated_at)
            VALUES ('day', '2026-10-12', 'One', '2026-10-12T09:00:00')
            """
        try execute(insertNote, in: database)
        try execute(
            """
            INSERT INTO note (scope, period, body, updated_at)
            VALUES ('week', '2026-10-12', 'Other scope', '2026-10-12T09:00:00')
            """,
            in: database
        )
        let error = #expect(throws: DatabaseError.self) {
            try execute(insertNote, in: database)
        }
        #expect(error?.extendedResultCode == .SQLITE_CONSTRAINT_UNIQUE)
    }

    @Test
    func rejectsASubtaskWithNoPriority() throws {
        let database = try AppDatabase.inMemory()
        let error = #expect(throws: DatabaseError.self) {
            try execute(
                """
                INSERT INTO subtask (id, priority_id, title, position, created_at)
                VALUES ('s1', 'missing', 'Title', 1, '2026-10-12T09:00:00')
                """,
                in: database
            )
        }
        #expect(error?.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY)
    }

    @Test
    func appDatabaseIsInMemoryInATestHost() throws {
        #expect(AppDatabase.isTestHost)
        #expect(try AppDatabase.forApp().path == ":memory:")
        #expect(AppDatabase.defaultURL.path.hasSuffix("/Library/Application Support/DailyZGT/daily-zgt.sqlite"))
    }
}
