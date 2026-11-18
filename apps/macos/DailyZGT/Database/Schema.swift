import Foundation
import GRDB

enum Schema {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("001_create_tables") { database in
            try database.execute(sql: """
                CREATE TABLE priority (
                    id TEXT PRIMARY KEY NOT NULL,
                    title TEXT NOT NULL,
                    note TEXT NOT NULL DEFAULT '',
                    level TEXT NOT NULL CHECK (level IN ('high', 'medium', 'low')),
                    list TEXT NOT NULL CHECK (list IN ('today', 'week')),
                    due_at TEXT,
                    done_at TEXT,
                    position INTEGER NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                CREATE INDEX priority_on_list_done_at ON priority (list, done_at);

                CREATE TABLE subtask (
                    id TEXT PRIMARY KEY NOT NULL,
                    priority_id TEXT NOT NULL REFERENCES priority (id) ON DELETE CASCADE,
                    title TEXT NOT NULL,
                    done_at TEXT,
                    position INTEGER NOT NULL,
                    created_at TEXT NOT NULL
                );
                CREATE INDEX subtask_on_priority_id_position ON subtask (priority_id, position);

                CREATE TABLE note (
                    scope TEXT NOT NULL CHECK (scope IN ('day', 'week')),
                    period TEXT NOT NULL,
                    body TEXT NOT NULL DEFAULT '',
                    updated_at TEXT NOT NULL,
                    UNIQUE (scope, period)
                );

                CREATE TABLE alert (
                    id TEXT PRIMARY KEY NOT NULL,
                    priority_id TEXT NOT NULL REFERENCES priority (id) ON DELETE CASCADE,
                    kind TEXT NOT NULL CHECK (kind IN ('before_30m', 'at_due', 'snooze')),
                    fire_at TEXT NOT NULL,
                    status TEXT NOT NULL CHECK (status IN ('scheduled', 'delivered', 'snoozed', 'cancelled'))
                );
                CREATE INDEX alert_on_priority_id ON alert (priority_id);

                CREATE TABLE priority_event (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    priority_id TEXT NOT NULL,
                    at TEXT NOT NULL,
                    type TEXT NOT NULL
                        CHECK (type IN ('created', 'edited', 'moved', 'done', 'restored', 'subtask_done'))
                );
                CREATE INDEX priority_event_on_priority_id_at ON priority_event (priority_id, at);

                CREATE TABLE app_state (
                    key TEXT PRIMARY KEY NOT NULL,
                    value TEXT NOT NULL
                );
                """)
        }
        migrator.registerMigration("002_add_repeat_to_priority") { database in
            try database.execute(sql: """
                ALTER TABLE priority ADD COLUMN repeat_rule TEXT NOT NULL DEFAULT 'none'
                    CHECK (repeat_rule IN ('none', 'daily'));
                ALTER TABLE priority ADD COLUMN repeat_series_id TEXT;
                """)
        }
        migrator.registerMigration("003_add_image") { database in
            try database.execute(sql: """
                CREATE TABLE image (
                    id TEXT PRIMARY KEY NOT NULL,
                    mime TEXT NOT NULL CHECK (mime IN ('image/png', 'image/jpeg')),
                    width INTEGER NOT NULL,
                    height INTEGER NOT NULL,
                    bytes BLOB NOT NULL,
                    created_at TEXT NOT NULL
                );
                """)
        }
        migrator.registerMigration("004_add_note_item") { database in
            try database.execute(sql: """
                CREATE TABLE note_item (
                    id TEXT PRIMARY KEY NOT NULL,
                    body TEXT NOT NULL DEFAULT '',
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                CREATE INDEX note_item_on_created_at ON note_item (created_at);
                """)
            let rows = try Row.fetchAll(database, sql: """
                SELECT scope, period, body, updated_at FROM note ORDER BY period, scope
                """)
            for row in rows {
                let body: String = row["body"]
                let updatedAt: String = row["updated_at"]
                guard !body.allSatisfy(\.isWhitespace) else { continue }
                let createdAt = LegacyNotePeriod.firstDay(scope: row["scope"], period: row["period"])
                    .map { "\($0)T00:00:00" } ?? updatedAt
                try database.execute(
                    sql: "INSERT INTO note_item (id, body, created_at, updated_at) VALUES (?, ?, ?, ?)",
                    arguments: [UUID().uuidString, body, createdAt, updatedAt]
                )
            }
        }
        return migrator
    }
}

enum LegacyNotePeriod {
    static func firstDay(scope: String, period: String) -> String? {
        switch scope {
        case "day":
            return LocalTime.day(from: period, in: .gmt) == nil ? nil : period
        case "week":
            let parts = period.split(separator: "-W")
            guard parts.count == 2, let year = Int(parts[0]), let week = Int(parts[1]) else { return nil }
            var calendar = Calendar(identifier: .iso8601)
            calendar.timeZone = .gmt
            let components = DateComponents(weekday: 2, weekOfYear: week, yearForWeekOfYear: year)
            guard let monday = calendar.date(from: components),
                  LocalTime.weekKey(for: monday, in: .gmt) == period else { return nil }
            return LocalTime.dayKey(for: monday, in: .gmt)
        default:
            return nil
        }
    }
}
