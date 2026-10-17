using DailyZGT.Core.Alerts;
using DailyZGT.Core.Domain;
using DailyZGT.Core.Localization;
using DailyZGT.Core.Store;
using DailyZGT.Core.Tests.Support;
using Microsoft.Extensions.Time.Testing;

namespace DailyZGT.Core.Tests.Alerts;

// A timer the test fires by hand. Firing a timer that was disposed still runs its callback, the way a
// callback already queued on the thread pool would.
internal sealed class ManualTimer(TimerCallback callback, object? state, TimeSpan wait) : ITimer
{
    public TimeSpan Wait { get; } = wait;

    public bool Disposed { get; private set; }

    public void Fire() => callback(state);

    public bool Change(TimeSpan dueTime, TimeSpan period) => throw new NotSupportedException();

    public void Dispose() => Disposed = true;

    public ValueTask DisposeAsync()
    {
        Dispose();
        return ValueTask.CompletedTask;
    }
}

// A clock the test moves with SetUtcNow or Advance. The timers the code creates wait for Fire.
internal sealed class ScriptedTime : FakeTimeProvider
{
    public List<ManualTimer> Timers { get; } = [];

    public IEnumerable<TimeSpan> Waits => Timers.Select(timer => timer.Wait);

    public void Set(string localText) => SetUtcNow(new DateTimeOffset(DateTime.SpecifyKind(Time.At(localText), DateTimeKind.Unspecified), TimeSpan.Zero));

    public override ITimer CreateTimer(TimerCallback callback, object? state, TimeSpan dueTime, TimeSpan period)
    {
        var timer = new ManualTimer(callback, state, dueTime);
        Timers.Add(timer);
        return timer;
    }
}

// The notification system in memory. Held is what the system would fire later, Delivered what it already showed.
internal sealed class FakeAlertSystem : IAlertSystem
{
    public AlertAuthorization Authorization { get; set; } = AlertAuthorization.Authorized;

    public Dictionary<string, AlertRequest> Held { get; } = [];

    public List<AlertRequest> Added { get; } = [];

    public List<IReadOnlyList<string>> RemovedPending { get; } = [];

    public List<IReadOnlyList<string>> RemovedDelivered { get; } = [];

    public List<string> Delivered { get; } = [];

    public int PendingReads { get; private set; }

    public int Starts { get; private set; }

    public bool FailSchedule { get; set; }

    public bool HasListener => Responded is not null;

    public event EventHandler<AlertResponse>? Responded;

    public void Respond(AlertResponse response) => Responded?.Invoke(this, response);

    public void Start() => Starts++;

    public IReadOnlyList<AlertRequest> Pending()
    {
        PendingReads++;
        return Held.Values.ToList();
    }

    public IReadOnlyList<string> DeliveredIds() => Delivered.ToList();

    public void Schedule(AlertRequest request)
    {
        if (FailSchedule)
        {
            throw new AlertSystemException("The system refused the toast.");
        }

        Held[request.Id] = request;
        Added.Add(request);
    }

    public void RemovePending(IEnumerable<string> ids)
    {
        var list = ids.ToList();
        RemovedPending.Add(list);
        foreach (var id in list)
        {
            Held.Remove(id);
        }
    }

    public void RemoveDelivered(IEnumerable<string> ids)
    {
        var list = ids.ToList();
        RemovedDelivered.Add(list);
        Delivered.RemoveAll(list.Contains);
    }
}

// A coordinator over a real store file, the fake system and a scripted clock that starts at 10:00 on 2026-10-12.
internal sealed class AlertHarness : IDisposable
{
    private readonly string folder = TempFolder.Create();

    public AlertHarness(Texts? texts = null, string start = "2026-10-12T10:00:00")
    {
        Time = new ScriptedTime();
        Time.Set(start);
        FilePath = Path.Combine(folder, AppDatabase.FileName);
        Store = AppStore.OpenFile(FilePath, Time);
        Alerts = new AlertCoordinator(Store, Toasts, texts ?? Texts.Es, Time);
        Alerts.OpenRequested += (_, request) => Opened.Add(request.PriorityId);
        Alerts.Failed += (_, error) => Failures.Add(error);
    }

    public ScriptedTime Time { get; }

    public FakeAlertSystem Toasts { get; } = new();

    public string FilePath { get; }

    public AppStore Store { get; }

    public AlertCoordinator Alerts { get; }

    public List<string?> Opened { get; } = [];

    public List<Exception> Failures { get; } = [];

    public AlertHarness Started()
    {
        Alerts.Start();
        return this;
    }

    public Priority AddBrief(string due = "2026-10-12T12:00:00", string title = "Terminar el brief", PriorityList list = PriorityList.Today) =>
        Store.Add(title, list, due: due);

    public List<AlertKind> Kinds() => Store.Alerts().Select(row => row.Kind).ToList();

    public List<AlertStatus> Statuses() => Store.Alerts().Select(row => row.Status).ToList();

    public List<DateTime> FireTimes() => Store.Alerts().Select(row => row.FireAt).ToList();

    public void Execute(string sql)
    {
        OutsideConnection.Execute(FilePath, sql);
        Assert.True(Store.CheckForExternalChanges());
    }

    public void Dispose()
    {
        Alerts.Dispose();
        Store.Dispose();
        TempFolder.Delete(folder);
    }
}
