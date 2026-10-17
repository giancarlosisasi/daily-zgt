using DailyZGT.Core.Domain;
using DailyZGT.Core.Store;
using DailyZGT.Core.Tests.Support;

namespace DailyZGT.Core.Tests.Store;

// A database file as the macOS app writes it. The SQL is copied from apps/macos/DailyZGT/Database/Schema.swift
// and GRDB's migrator, not from the Windows schema, so these tests catch a drift between the two apps.
internal static class MacFile
{
    public const string MigrationsTable = "CREATE TABLE grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)";

    public const string FirstMigration = """
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
        INSERT INTO grdb_migrations (identifier) VALUES ('001_create_tables');
        """;

    public const string SecondMigration = """
        ALTER TABLE priority ADD COLUMN repeat_rule TEXT NOT NULL DEFAULT 'none'
            CHECK (repeat_rule IN ('none', 'daily'));
        ALTER TABLE priority ADD COLUMN repeat_series_id TEXT;
        INSERT INTO grdb_migrations (identifier) VALUES ('002_add_repeat_to_priority');
        """;

    public const string Rows = """
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
        """;

    public static readonly string[] Tables = ["priority", "subtask", "note", "alert", "priority_event", "app_state"];

    // Writes the file the way the macOS app does: WAL, each migration in its own transaction.
    public static void Write(string path, bool withSecondMigration)
    {
        using var connection = OutsideConnection.Open(path);
        OutsideConnection.Execute(connection, "PRAGMA journal_mode = WAL");
        OutsideConnection.Execute(connection, MigrationsTable);
        OutsideConnection.Execute(connection, $"BEGIN; {FirstMigration} COMMIT;");
        if (withSecondMigration)
        {
            OutsideConnection.Execute(connection, $"BEGIN; {SecondMigration} COMMIT;");
        }
        OutsideConnection.Execute(connection, Rows);
    }

    // Every row of the six tables as text, in the columns of the first schema.
    public static Dictionary<string, List<string>> Contents(string path) => new()
    {
        ["priority"] = OutsideConnection.Rows<string>(path, """
            SELECT id || '|' || title || '|' || note || '|' || level || '|' || list || '|' || IFNULL(due_at, '-') || '|' ||
                IFNULL(done_at, '-') || '|' || position || '|' || created_at || '|' || updated_at
            FROM priority ORDER BY id
            """),
        ["subtask"] = OutsideConnection.Rows<string>(path,
            "SELECT id || '|' || priority_id || '|' || title || '|' || IFNULL(done_at, '-') || '|' || position || '|' || created_at FROM subtask ORDER BY id"),
        ["note"] = OutsideConnection.Rows<string>(path,
            "SELECT scope || '|' || period || '|' || body || '|' || updated_at FROM note ORDER BY scope, period"),
        ["alert"] = OutsideConnection.Rows<string>(path,
            "SELECT id || '|' || priority_id || '|' || kind || '|' || fire_at || '|' || status FROM alert ORDER BY id"),
        ["priority_event"] = OutsideConnection.Rows<string>(path,
            "SELECT id || '|' || priority_id || '|' || at || '|' || type FROM priority_event ORDER BY id"),
        ["app_state"] = OutsideConnection.Rows<string>(path, "SELECT key || '|' || value FROM app_state ORDER BY key"),
    };
}

public sealed class MacFileTests : IDisposable
{
    private readonly string _folder = TempFolder.Create();
    private readonly string _path;

    public MacFileTests() => _path = Path.Combine(_folder, AppDatabase.FileName);

    public void Dispose() => TempFolder.Delete(_folder);

    private AppStore Open(string now = "2026-10-12T10:00:00") => AppStore.OpenFile(_path, new TestClock(now));

    [Fact]
    public void AFileWithTheFirstMacSchemaMigratesAndKeepsEachRowOfEachTable()
    {
        MacFile.Write(_path, withSecondMigration: false);
        var before = MacFile.Contents(_path);

        using (Open()) { }

        var after = MacFile.Contents(_path);
        Assert.Equal(3, before["priority"].Count);
        Assert.Equal(3, before["subtask"].Count);
        Assert.Equal(3, before["alert"].Count);
        Assert.Equal(7, before["priority_event"].Count);
        Assert.Equal(2, before["note"].Count);
        Assert.Equal(2, before["app_state"].Count);
        foreach (var table in MacFile.Tables)
        {
            Assert.Equal(before[table], after[table]);
        }
        Assert.Equal(
            ["001_create_tables", "002_add_repeat_to_priority"],
            OutsideConnection.Rows<string>(_path, "SELECT identifier FROM grdb_migrations ORDER BY identifier"));
    }

    [Fact]
    public void TheMigratedRowsHaveTheRuleNoneAndNoSeries()
    {
        MacFile.Write(_path, withSecondMigration: false);
        using var store = Open();

        Assert.Equal(["none", "none", "none"], OutsideConnection.Rows<string>(_path, "SELECT repeat_rule FROM priority ORDER BY id"));
        Assert.Equal([3L], OutsideConnection.Rows<long>(_path, "SELECT COUNT(*) FROM priority WHERE repeat_series_id IS NULL"));
        var all = store.Snapshot.Open.Concat(store.Snapshot.Done).OrderBy(p => p.Id).ToList();
        Assert.All(all, p => Assert.Equal(RepeatRule.None, p.RepeatRule));
        Assert.Equal(["p1", "p2", "p3"], all.Select(p => p.SeriesId));
        Assert.Equal(Time.At("2026-10-12T08:00:00"), all[0].DueAt);
    }

    [Fact]
    public void TheStoreReadsTheRowsTheMacOSAppWrote()
    {
        MacFile.Write(_path, withSecondMigration: false);
        using var store = Open();

        Assert.Equal(["Meditar", "Sin nada"], store.OpenPriorities(PriorityList.Today).Titles());
        Assert.Equal([RepeatRule.None], store.DonePriorities(PriorityList.Week).Select(p => p.RepeatRule));
        Assert.Equal(["Respirar", "Estirar"], store.Subtasks("p1").Select(s => s.Title));
        Assert.Equal(Time.At("2026-10-12T07:30:00"), store.Subtasks("p1")[0].DoneAt);
        Assert.Equal(["a3", "a1", "a2"], store.Alerts().Select(a => a.Id));
        Assert.Equal("Llamar a Ana", store.NoteBody(NoteScope.Day));
        Assert.Equal("Cerrar el brief", store.NoteBody(NoteScope.Week));
        Assert.Equal(PanelTab.Notes, store.Value(AppStateKeys.OpenTab));
        Assert.True(store.Value(AppStateKeys.DoneOpen));
        Assert.Equal([PriorityEventType.Created, PriorityEventType.SubtaskDone], store.Types("p1"));
    }

    [Fact]
    public void TheMigrationKeepsTheForeignKeysAndTheIndexes()
    {
        MacFile.Write(_path, withSecondMigration: false);
        using var store = Open();

        Assert.Empty(OutsideConnection.Rows<string>(_path, "PRAGMA foreign_key_check"));
        Assert.Equal(["ok"], OutsideConnection.Rows<string>(_path, "PRAGMA integrity_check"));
        Assert.Equal(
            ["priority_on_list_done_at"],
            OutsideConnection.Rows<string>(_path, "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'priority' AND name NOT LIKE 'sqlite_%'"));

        store.Delete("p1");

        Assert.Equal(["s3"], OutsideConnection.Rows<string>(_path, "SELECT id FROM subtask ORDER BY id"));
        Assert.Equal(["a3"], OutsideConnection.Rows<string>(_path, "SELECT id FROM alert ORDER BY id"));
        Assert.Equal([2L], OutsideConnection.Rows<long>(_path, "SELECT COUNT(*) FROM priority_event WHERE priority_id = 'p1'"));
    }

    [Fact]
    public void AMigratedFileHasTheSameColumnsAsANewOne()
    {
        MacFile.Write(_path, withSecondMigration: false);
        using (Open()) { }
        using var fresh = new TestStore();
        const string columns = "SELECT name || ':' || type || ':' || \"notnull\" || ':' || IFNULL(dflt_value, '-') FROM pragma_table_info('priority') ORDER BY cid";
        Assert.Equal(fresh.Rows<string>(columns), OutsideConnection.Rows<string>(_path, columns));
    }

    [Fact]
    public void AFileWithBothMacMigrationsOpensWithoutRunningThemAgain()
    {
        MacFile.Write(_path, withSecondMigration: true);
        var before = MacFile.Contents(_path);

        using (var store = Open())
        {
            Assert.Equal(["Meditar", "Sin nada"], store.OpenPriorities(PriorityList.Today).Titles());
        }
        using (Open()) { }

        Assert.Equal(before, MacFile.Contents(_path));
        Assert.Equal([2L], OutsideConnection.Rows<long>(_path, "SELECT COUNT(*) FROM grdb_migrations"));
    }

    [Fact]
    public void ARowWithAnUnreadableTimeFailsTheOpenAndReleasesTheFile()
    {
        MacFile.Write(_path, withSecondMigration: true);
        OutsideConnection.Execute(_path, "UPDATE priority SET created_at = '12/10/2026 09:00' WHERE id = 'p3'");

        Assert.Throws<StoreException>(() => Open());

        File.Delete(_path);
        Assert.False(File.Exists(_path));
    }

    [Fact]
    public void TheWindowsAppWritesRowsTheMacOSAppReadsTheSameWay()
    {
        MacFile.Write(_path, withSecondMigration: true);
        using (var store = Open("2026-10-12T16:00:00"))
        {
            var added = store.Add("Desde Windows", PriorityList.Week, PriorityLevel.High, due: "2026-10-13T09:30:00");
            store.MarkDone("p3");
            store.SetValue(AppStateKeys.OpenScope, PriorityList.Week);
            store.SaveNote(NoteScope.Day, "Llamar a Ana y a Luis");
            Assert.Equal(4, added.Position);
        }

        Assert.Equal(
            ["Desde Windows|high|week|2026-10-13T09:30:00|2026-10-12T16:00:00|none"],
            OutsideConnection.Rows<string>(_path,
                "SELECT title || '|' || level || '|' || list || '|' || due_at || '|' || created_at || '|' || repeat_rule FROM priority WHERE title = 'Desde Windows'"));
        Assert.Equal(["2026-10-12T16:00:00"], OutsideConnection.Rows<string>(_path, "SELECT done_at FROM priority WHERE id = 'p3'"));
        Assert.Equal(["\"week\""], OutsideConnection.Rows<string>(_path, "SELECT value FROM app_state WHERE key = 'open_scope'"));
        Assert.Equal(["Llamar a Ana y a Luis"], OutsideConnection.Rows<string>(_path, "SELECT body FROM note WHERE scope = 'day' AND period = '2026-10-12'"));
    }
}
