using System.Diagnostics;
using DailyZGT.Core.Domain;
using DailyZGT.Core.Store;
using DailyZGT.Core.Tests.Support;
using Microsoft.Data.Sqlite;

namespace DailyZGT.Core.Tests.Store;

public sealed class SchemaTests : IDisposable
{
    private const string ValidPriority = """
        INSERT INTO priority (id, title, level, list, position, created_at, updated_at)
        VALUES ('p1', 'Title', 'high', 'today', 1, '2026-10-12T09:00:00', '2026-10-12T09:00:00')
        """;

    private const int ConstraintCheck = 275;
    private const int ConstraintUnique = 2067;
    private const int ConstraintForeignKey = 787;

    private readonly TestStore _test = new();

    public void Dispose() => _test.Dispose();

    [Fact]
    public void CreatesTheSixTables()
    {
        var tables = _test.Rows<string>("""
            SELECT name FROM sqlite_master
            WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name <> 'grdb_migrations'
            ORDER BY name
            """);
        Assert.Equal(["alert", "app_state", "note", "priority", "priority_event", "subtask"], tables);
    }

    [Theory]
    [InlineData("priority", "id,title,note,level,list,due_at,done_at,position,created_at,updated_at,repeat_rule,repeat_series_id")]
    [InlineData("subtask", "id,priority_id,title,done_at,position,created_at")]
    [InlineData("note", "scope,period,body,updated_at")]
    [InlineData("alert", "id,priority_id,kind,fire_at,status")]
    [InlineData("priority_event", "id,priority_id,at,type")]
    [InlineData("app_state", "key,value")]
    public void TableHasThePlannedColumns(string table, string columns)
    {
        var names = _test.Rows<string>($"SELECT name FROM pragma_table_info('{table}') ORDER BY cid");
        Assert.Equal(columns.Split(','), names);
    }

    [Fact]
    public void RecordsBothMigrationsInTheTableTheMacOSAppReads()
    {
        Assert.Equal(
            ["001_create_tables", "002_add_repeat_to_priority"],
            _test.Rows<string>("SELECT identifier FROM grdb_migrations ORDER BY identifier"));
    }

    [Theory]
    [InlineData("INSERT INTO priority (id, title, level, list, position, created_at, updated_at) VALUES ('p2', 'Title', 'urgent', 'today', 1, '2026-10-12T09:00:00', '2026-10-12T09:00:00')")]
    [InlineData("INSERT INTO priority (id, title, level, list, position, created_at, updated_at) VALUES ('p2', 'Title', 'high', 'month', 1, '2026-10-12T09:00:00', '2026-10-12T09:00:00')")]
    [InlineData("INSERT INTO note (scope, period, body, updated_at) VALUES ('month', '2026-10', '', '2026-10-12T09:00:00')")]
    [InlineData("INSERT INTO alert (id, priority_id, kind, fire_at, status) VALUES ('a1', 'p1', 'later', '2026-10-12T15:30:00', 'scheduled')")]
    [InlineData("INSERT INTO alert (id, priority_id, kind, fire_at, status) VALUES ('a1', 'p1', 'at_due', '2026-10-12T15:30:00', 'lost')")]
    [InlineData("INSERT INTO priority_event (priority_id, at, type) VALUES ('p1', '2026-10-12T09:00:00', 'deleted')")]
    [InlineData("UPDATE priority SET repeat_rule = 'weekly' WHERE id = 'p1'")]
    public void RejectsAValueOutsideItsSet(string sql)
    {
        _test.Execute(ValidPriority);
        var error = Assert.Throws<SqliteException>(() => _test.Execute(sql));
        Assert.Equal(ConstraintCheck, error.SqliteExtendedErrorCode);
    }

    [Fact]
    public void TheStoreWritesEachValueOfTheSetsAsTheMacOSText()
    {
        var store = _test.Store;
        var priority = store.Add("Title", PriorityList.Week);
        var alerts = Enum.GetValues<AlertKind>()
            .SelectMany(kind => Enum.GetValues<AlertStatus>().Select(status =>
                new PriorityAlert($"{kind}-{status}", priority.Id, kind, Time.At("2026-10-12T12:00:00"), status)));
        store.SaveAlerts(alerts);
        store.EditTitle(priority.Id, "Other");
        store.MoveToList(priority.Id, PriorityList.Today);
        var subtask = store.AddSubtask(priority.Id, "Step")!;
        store.ToggleSubtask(subtask.Id);
        store.MarkDone(priority.Id);
        store.Restore(priority.Id);

        Assert.Equal(["at_due", "before_30m", "snooze"], _test.Rows<string>("SELECT DISTINCT kind FROM alert ORDER BY kind"));
        Assert.Equal(
            ["cancelled", "delivered", "scheduled", "snoozed"],
            _test.Rows<string>("SELECT DISTINCT status FROM alert ORDER BY status"));
        Assert.Equal(
            ["created", "edited", "moved", "edited", "subtask_done", "done", "restored"],
            _test.Rows<string>("SELECT type FROM priority_event ORDER BY id"));
    }

    [Fact]
    public void ANoteIsUniqueByScopeAndPeriod()
    {
        const string insertNote = "INSERT INTO note (scope, period, body, updated_at) VALUES ('day', '2026-10-12', 'One', '2026-10-12T09:00:00')";
        _test.Execute(insertNote);
        _test.Execute("INSERT INTO note (scope, period, body, updated_at) VALUES ('week', '2026-10-12', 'Other scope', '2026-10-12T09:00:00')");
        var error = Assert.Throws<SqliteException>(() => _test.Execute(insertNote));
        Assert.Equal(ConstraintUnique, error.SqliteExtendedErrorCode);
    }

    [Fact]
    public void ASubtaskNeedsItsPriority()
    {
        var error = Assert.Throws<SqliteException>(() => _test.Execute(
            "INSERT INTO subtask (id, priority_id, title, position, created_at) VALUES ('s1', 'missing', 'Title', 1, '2026-10-12T09:00:00')"));
        Assert.Equal(ConstraintForeignKey, error.SqliteExtendedErrorCode);
    }

    [Fact]
    public void TheFileUsesWAL()
    {
        _test.Store.Add("Written");
        Assert.Equal(["wal"], _test.Rows<string>("PRAGMA journal_mode"));
        Assert.True(File.Exists(_test.FilePath + "-wal"));
    }

    [Fact]
    public void TheStoreCreatesTheMissingFolders()
    {
        var folder = TempFolder.Create();
        try
        {
            var path = Path.Combine(folder, "nested", "deeper", AppDatabase.FileName);
            using (var store = AppStore.OpenFile(path, new TestClock()))
            {
                store.Add("Written");
            }
            Assert.Equal([1L], OutsideConnection.Rows<long>(path, "SELECT COUNT(*) FROM priority"));
        }
        finally
        {
            TempFolder.Delete(folder);
        }
    }

    [Fact]
    public void AWriteWaitsAboutTwoSecondsForAnotherWriterThenFails()
    {
        using var other = OutsideConnection.Open(_test.FilePath);
        OutsideConnection.Execute(other, "BEGIN IMMEDIATE");
        var watch = Stopwatch.StartNew();

        Assert.Throws<StoreException>(() => _test.Store.Add("Blocked"));

        watch.Stop();
        Assert.InRange(watch.Elapsed.TotalSeconds, 1.9, 6);
        OutsideConnection.Execute(other, "ROLLBACK");
        Assert.Equal("Later", _test.Store.Add("Later").Title);
    }

    [Fact]
    public void AnInMemoryStoreHasTheSameRulesAndNoFile()
    {
        using var store = AppStore.OpenInMemory(new TestClock());
        var added = store.Add("In memory");
        store.AddSubtask(added.Id, "Step");
        store.Delete(added.Id);
        Assert.Empty(store.Snapshot.Open);
        Assert.Empty(store.Subtasks(added.Id));
        Assert.False(store.CheckForExternalChanges());
    }

    [Fact]
    public void TheDefaultFileIsInLocalAppDataUnlessTheVariableNamesAFolder()
    {
        var saved = Environment.GetEnvironmentVariable(AppDatabase.DataDirVariable);
        try
        {
            Environment.SetEnvironmentVariable(AppDatabase.DataDirVariable, null);
            Assert.Equal(
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DailyZGT", "daily-zgt.sqlite"),
                AppDatabase.DefaultPath());

            Environment.SetEnvironmentVariable(AppDatabase.DataDirVariable, @"C:\Tests\Data");
            Assert.Equal(@"C:\Tests\Data\daily-zgt.sqlite", AppDatabase.DefaultPath());
        }
        finally
        {
            Environment.SetEnvironmentVariable(AppDatabase.DataDirVariable, saved);
        }
    }

    [Fact]
    public void AFileThatIsNotADatabaseFailsWithTheStoreError()
    {
        var folder = TempFolder.Create();
        try
        {
            var path = Path.Combine(folder, AppDatabase.FileName);
            File.WriteAllText(path, "This is not a SQLite file, it is long enough to have a header of one hundred bytes or more ...........");
            Assert.Throws<StoreException>(() => AppStore.OpenFile(path, new TestClock()));
        }
        finally
        {
            TempFolder.Delete(folder);
        }
    }
}
