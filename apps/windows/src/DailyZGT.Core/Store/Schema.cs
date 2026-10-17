using Microsoft.Data.Sqlite;

namespace DailyZGT.Core.Store;

// The same migrations, SQL and bookkeeping table as the macOS app (GRDB's DatabaseMigrator),
// so a file written by either app opens and migrates the same way in the other.
internal static class Schema
{
    public const string MigrationsTable = "grdb_migrations";

    public static readonly IReadOnlyList<(string Identifier, string Sql)> Migrations =
    [
        ("001_create_tables", """
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
            """),
        ("002_add_repeat_to_priority", """
            ALTER TABLE priority ADD COLUMN repeat_rule TEXT NOT NULL DEFAULT 'none'
                CHECK (repeat_rule IN ('none', 'daily'));
            ALTER TABLE priority ADD COLUMN repeat_series_id TEXT;
            """),
    ];

    public static void Migrate(SqliteConnection connection)
    {
        Execute(connection, null, $"CREATE TABLE IF NOT EXISTS {MigrationsTable} (identifier TEXT NOT NULL PRIMARY KEY)");
        var applied = new HashSet<string>();
        using (var read = connection.CreateCommand())
        {
            read.CommandText = $"SELECT identifier FROM {MigrationsTable}";
            using var reader = read.ExecuteReader();
            while (reader.Read())
            {
                applied.Add(reader.GetString(0));
            }
        }

        foreach (var (identifier, sql) in Migrations.Where(m => !applied.Contains(m.Identifier)))
        {
            using var transaction = connection.BeginTransaction();
            Execute(connection, transaction, sql);
            Execute(connection, transaction, $"INSERT INTO {MigrationsTable} (identifier) VALUES ($identifier)", identifier);
            transaction.Commit();
        }
    }

    private static void Execute(SqliteConnection connection, SqliteTransaction? transaction, string sql, string? identifier = null)
    {
        using var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = sql;
        if (identifier is not null)
        {
            command.Parameters.AddWithValue("$identifier", identifier);
        }
        command.ExecuteNonQuery();
    }
}
