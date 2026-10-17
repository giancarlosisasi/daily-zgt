using DailyZGT.Core.Domain;
using DailyZGT.Core.Store;
using Microsoft.Data.Sqlite;

namespace DailyZGT.Core.Tests.Support;

// A store on a file in a fresh temp folder. Raw SQL goes through a second connection, the way another
// program (or the macOS app) sees the file.
public sealed class TestStore : IDisposable
{
    public TestStore(TestClock? clock = null)
    {
        Clock = clock ?? new TestClock();
        Folder = TempFolder.Create();
        FilePath = Path.Combine(Folder, AppDatabase.FileName);
        Store = Open();
    }

    public TestClock Clock { get; }

    public string Folder { get; }

    public string FilePath { get; }

    public AppStore Store { get; private set; }

    public int Changes { get; private set; }

    public AppStore Reopen()
    {
        Store.Dispose();
        Store = Open();
        return Store;
    }

    public List<T> Rows<T>(string sql) => OutsideConnection.Rows<T>(FilePath, sql);

    public void Execute(string sql) => OutsideConnection.Execute(FilePath, sql);

    public void Dispose()
    {
        Store.Dispose();
        TempFolder.Delete(Folder);
    }

    private AppStore Open()
    {
        var store = AppStore.OpenFile(FilePath, Clock);
        store.Changed += (_, _) => Changes++;
        return store;
    }
}

public static class OutsideConnection
{
    public static SqliteConnection Open(string path)
    {
        var connection = new SqliteConnection(new SqliteConnectionStringBuilder { DataSource = path, Pooling = false }.ToString());
        connection.Open();
        using var command = connection.CreateCommand();
        command.CommandText = "PRAGMA foreign_keys = ON";
        command.ExecuteNonQuery();
        return connection;
    }

    public static List<T> Rows<T>(string path, string sql)
    {
        using var connection = Open(path);
        return Rows<T>(connection, sql);
    }

    public static List<T> Rows<T>(SqliteConnection connection, string sql)
    {
        using var command = connection.CreateCommand();
        command.CommandText = sql;
        using var reader = command.ExecuteReader();
        var rows = new List<T>();
        while (reader.Read())
        {
            rows.Add(reader.IsDBNull(0) ? default! : (T)Convert.ChangeType(reader.GetValue(0), Nullable.GetUnderlyingType(typeof(T)) ?? typeof(T)));
        }
        return rows;
    }

    public static void Execute(string path, string sql)
    {
        using var connection = Open(path);
        Execute(connection, sql);
    }

    public static void Execute(SqliteConnection connection, string sql)
    {
        using var command = connection.CreateCommand();
        command.CommandText = sql;
        command.ExecuteNonQuery();
    }
}

public static class TempFolder
{
    public static string Create()
    {
        var folder = Path.Combine(Path.GetTempPath(), "DailyZGTTests", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(folder);
        return folder;
    }

    public static void Delete(string folder)
    {
        if (Directory.Exists(folder))
        {
            Directory.Delete(folder, recursive: true);
        }
    }
}

public static class StoreSteps
{
    public static Priority Add(
        this AppStore store,
        string title,
        PriorityList list = PriorityList.Today,
        PriorityLevel level = PriorityLevel.Medium,
        string? due = null,
        string note = "") =>
        store.AddPriority(title, list, level, due is null ? null : Time.At(due), note) is AddOutcome.Added added
            ? added.Priority
            : throw new InvalidOperationException($"'{title}' was not added.");

    public static Priority AddDaily(
        this AppStore store,
        string title = "Meditar",
        PriorityList list = PriorityList.Today,
        PriorityLevel level = PriorityLevel.Medium,
        string? due = null,
        string note = "") =>
        store.SetRepeat(store.Add(title, list, level, due, note).Id, RepeatRule.Daily);

    public static Priority DoneDaily(this AppStore store, string title = "Meditar", PriorityList list = PriorityList.Today, string? due = null) =>
        store.MarkDone(store.AddDaily(title, list, due: due).Id);

    public static List<PriorityEventType> Types(this AppStore store, string id) => store.Events(id).Select(e => e.Type).ToList();

    public static List<string> Titles(this IEnumerable<Priority> priorities) => priorities.Select(p => p.Title).ToList();

    public static List<string> Ids(this IEnumerable<Priority> priorities) => priorities.Select(p => p.Id).ToList();
}
