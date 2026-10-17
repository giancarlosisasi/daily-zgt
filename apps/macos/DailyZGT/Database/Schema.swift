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
        return migrator
    }
}
