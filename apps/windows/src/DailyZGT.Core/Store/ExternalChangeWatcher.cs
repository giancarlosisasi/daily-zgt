namespace DailyZGT.Core.Store;

// F20. Polls PRAGMA data_version through the store on the UI thread. A file watcher on the -wal file is not
// reliable on Windows: NTFS reports writes to a file another process keeps open late or not at all, and
// SQLite reuses the -wal file at the same size after a checkpoint.
public sealed class ExternalChangeWatcher : IDisposable
{
    public static readonly TimeSpan DefaultInterval = TimeSpan.FromSeconds(1);

    private readonly ITimer _timer;
    private bool _disposed;

    // The context is the UI thread's (WPF's DispatcherSynchronizationContext), because the store is not thread-safe.
    public ExternalChangeWatcher(AppStore store, SynchronizationContext uiThread, TimeProvider clock, TimeSpan? interval = null)
    {
        var period = interval ?? DefaultInterval;
        _timer = clock.CreateTimer(_ => uiThread.Post(_ => Check(store), null), null, period, period);
    }

    public void Dispose()
    {
        _disposed = true;
        _timer.Dispose();
    }

    private void Check(AppStore store)
    {
        if (_disposed)
        {
            return;
        }
        try
        {
            store.CheckForExternalChanges();
        }
        catch (StoreException)
        {
            // Another writer can hold the file longer than the busy timeout. The next tick reads again.
        }
    }
}
