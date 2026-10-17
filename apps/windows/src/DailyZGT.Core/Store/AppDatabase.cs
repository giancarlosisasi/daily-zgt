using Microsoft.Data.Sqlite;

namespace DailyZGT.Core.Store;

public static class AppDatabase
{
    public const string DataDirVariable = "DAILYZGT_DATA_DIR";
    public const string FileName = "daily-zgt.sqlite";

    // %LOCALAPPDATA%\DailyZGT\daily-zgt.sqlite, or DAILYZGT_DATA_DIR\daily-zgt.sqlite when the variable is set.
    public static string DefaultPath()
    {
        var folder = Environment.GetEnvironmentVariable(DataDirVariable);
        if (string.IsNullOrEmpty(folder))
        {
            folder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DailyZGT");
        }
        return Path.Combine(folder, FileName);
    }

    internal static SqliteConnection OpenFile(string path)
    {
        var full = Path.GetFullPath(path);
        Directory.CreateDirectory(Path.GetDirectoryName(full)!);
        var connection = Connect(full);
        try
        {
            Pragma(connection, "journal_mode = WAL");
            return Migrated(connection);
        }
        catch
        {
            connection.Dispose();
            throw;
        }
    }

    internal static SqliteConnection OpenInMemory() => Migrated(Connect(":memory:"));

    // Pooling is off so that closing the store releases the file, the way the macOS app does.
    // DefaultTimeout bounds Microsoft.Data.Sqlite's own busy retry loop to the same 2 s as busy_timeout.
    private static SqliteConnection Connect(string dataSource)
    {
        var connection = new SqliteConnection(new SqliteConnectionStringBuilder
        {
            DataSource = dataSource,
            Pooling = false,
            DefaultTimeout = 2,
        }.ToString());
        connection.Open();
        Pragma(connection, "busy_timeout = 2000");
        Pragma(connection, "foreign_keys = ON");
        return connection;
    }

    private static SqliteConnection Migrated(SqliteConnection connection)
    {
        Schema.Migrate(connection);
        return connection;
    }

    private static void Pragma(SqliteConnection connection, string pragma)
    {
        using var command = connection.CreateCommand();
        command.CommandText = $"PRAGMA {pragma}";
        command.ExecuteNonQuery();
    }
}
