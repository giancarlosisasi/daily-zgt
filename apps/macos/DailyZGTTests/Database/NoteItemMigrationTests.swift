import Foundation
import GRDB
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct NoteItemMigrationTests {
    static let oldNotes = """
        INSERT INTO note (scope, period, body, updated_at) VALUES
            ('day', '2026-10-12', '# Lunes' || char(10) || 'Llamar a Ana', '2026-10-12T18:00:00'),
            ('week', '2026-W42', 'Cerrar el brief', '2026-10-14T09:05:00'),
            ('day', '2026-10-13', '  ' || char(10) || '  ', '2026-10-13T08:00:00'),
            ('week', '2026-W43', '', '2026-10-19T08:00:00'),
            ('week', '2026-W01', 'Plan del año', '2026-01-02T10:00:00'),
            ('day', 'not-a-day', 'Texto suelto', '2026-10-01T07:30:00');
        """

    private func migrated() throws -> DatabaseQueue {
        let database = try DatabaseQueue()
        try Schema.migrator.migrate(database, upTo: "003_add_image")
        try execute(Self.oldNotes, in: database)
        try Schema.migrator.migrate(database)
        return database
    }

    private func items(_ database: DatabaseQueue) throws -> [[String]] {
        try database.read { database in
            try Row.fetchAll(database, sql: "SELECT body, created_at, updated_at FROM note_item ORDER BY created_at, body").map {
                [$0["body"], $0["created_at"], $0["updated_at"]]
            }
        }
    }

    @Test
    func eachNonEmptyOldNoteBecomesOneNoteOnTheFirstDayOfItsPeriod() throws {
        let database = try migrated()
        #expect(try items(database) == [
            ["Plan del año", "2025-12-29T00:00:00", "2026-01-02T10:00:00"],
            ["Texto suelto", "2026-10-01T07:30:00", "2026-10-01T07:30:00"],
            ["# Lunes\nLlamar a Ana", "2026-10-12T00:00:00", "2026-10-12T18:00:00"],
            ["Cerrar el brief", "2026-10-12T00:00:00", "2026-10-14T09:05:00"],
        ])
        let ids: [String] = try values("SELECT id FROM note_item", in: database)
        #expect(Set(ids).count == 4)
        #expect(ids.allSatisfy { UUID(uuidString: $0) != nil })
    }

    @Test
    func theOldNoteTableStaysAsItWas() throws {
        let database = try migrated()
        let rows: [String] = try values("SELECT scope || '|' || period || '|' || body FROM note ORDER BY scope, period", in: database)
        #expect(rows.count == 6)
        #expect(rows.contains("day|2026-10-12|# Lunes\nLlamar a Ana"))
        #expect(rows.contains("week|2026-W43|"))
        let migrations: [String] = try values("SELECT identifier FROM grdb_migrations ORDER BY identifier", in: database)
        #expect(migrations.last == "004_add_note_item")
    }

    @Test
    func theMigrationRunsOnceWhenTheFileOpensAgain() throws {
        let url = try temporaryFolder("note-item-migration").appending(path: "daily-zgt.sqlite")
        let old = try DatabaseQueue(path: url.path)
        try Schema.migrator.migrate(old, upTo: "003_add_image")
        try execute(Self.oldNotes, in: old)
        try old.close()

        let first = try AppDatabase.onDisk(at: url)
        let firstCount: [Int] = try values("SELECT COUNT(*) FROM note_item", in: first)
        #expect(firstCount == [4])
        try first.close()
        let second = try AppDatabase.onDisk(at: url)
        let secondCount: [Int] = try values("SELECT COUNT(*) FROM note_item", in: second)
        #expect(secondCount == [4])
    }

    @Test
    func theCopiedNotesShowUnderTheFilterOfTheirPeriod() throws {
        let store = AppStore(database: try migrated(), now: { localDate("2026-10-14T10:00:00") })
        #expect(Set(store.notes(in: .week).map(\.body)) == ["Cerrar el brief", "# Lunes\nLlamar a Ana"])
        #expect(Set(store.notes(in: .day("2026-10-12")).map(\.body)) == ["Cerrar el brief", "# Lunes\nLlamar a Ana"])
        #expect(store.notes(in: .today).isEmpty)
        #expect(store.notes(in: .all).count == 4)
    }

    @Test
    func theWeekKeyGivesItsMonday() {
        #expect(LegacyNotePeriod.firstDay(scope: "week", period: "2026-W42") == "2026-10-12")
        #expect(LegacyNotePeriod.firstDay(scope: "week", period: "2026-W01") == "2025-12-29")
        #expect(LegacyNotePeriod.firstDay(scope: "week", period: "2020-W53") == "2020-12-28")
        #expect(LegacyNotePeriod.firstDay(scope: "week", period: "2026-W60") == nil)
        #expect(LegacyNotePeriod.firstDay(scope: "day", period: "2026-10-12") == "2026-10-12")
        #expect(LegacyNotePeriod.firstDay(scope: "day", period: "12/10/2026") == nil)
        #expect(LegacyNotePeriod.firstDay(scope: "month", period: "2026-10") == nil)
    }
}
