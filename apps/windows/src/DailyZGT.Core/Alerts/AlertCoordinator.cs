using DailyZGT.Core.Domain;
using DailyZGT.Core.Localization;
using DailyZGT.Core.Store;

namespace DailyZGT.Core.Alerts;

// Which priority the panel must show after the user opened a toast. PriorityId is null for the test alert:
// the panel opens on Prioridades and Hoy with no highlight.
public sealed record AlertOpenRequest(string? PriorityId);

// F15. Keeps the toasts of the system equal to the alert rows of the store. It reconciles at start, after a
// change of the open priorities, on Refresh (the app calls it when the panel comes to the front and when the
// day changes) and one second after each alert fires. Everything runs on the UI thread.
public sealed class AlertCoordinator : IDisposable
{
    public static readonly TimeSpan TestDelay = TimeSpan.FromSeconds(5);
    public static readonly TimeSpan WakeMargin = TimeSpan.FromSeconds(1);

    // IAlertSystem.Schedule shows a toast at once when its fire time is this close. Such a toast sits in
    // DeliveredIds while its row is still scheduled, and scheduling it again would show it twice.
    public static readonly TimeSpan ShownAtOnce = TimeSpan.FromSeconds(1);

    // A timer cannot wait longer than about 49 days. The wake only re-reads the plan, so a shorter wait is safe.
    public static readonly TimeSpan WakeLimit = TimeSpan.FromDays(7);

    private readonly AppStore _store;
    private readonly IAlertSystem _system;
    private readonly Texts _texts;
    private readonly TimeProvider _time;
    private readonly SynchronizationContext? _context;
    private IReadOnlyList<AlertSubject>? _lastSubjects;
    private ITimer? _wakeTimer;
    private DateTime? _wakeAt;
    private int _wakeToken;
    private int _generation;
    private bool _forced;
    private bool _running;
    private bool _started;
    private bool _disposed;

    // `context` is where the wake timer hands its work back. The app passes the UI context. Without it the
    // wake runs on the timer thread, which only tests do.
    public AlertCoordinator(
        AppStore store,
        IAlertSystem system,
        Texts texts,
        TimeProvider time,
        SynchronizationContext? context = null)
    {
        _store = store;
        _system = system;
        _texts = texts;
        _time = time;
        _context = context;
    }

    public AlertAuthorization Authorization { get; private set; } = AlertAuthorization.Authorized;

    // The footer shows "Las alertas están desactivadas." with `Abrir ajustes` while this is true.
    public bool AlertsAreOff => Authorization == AlertAuthorization.Denied;

    public event EventHandler? AuthorizationChanged;

    public event EventHandler<AlertOpenRequest>? OpenRequested;

    // A store or system call failed. The next change, refresh or wake tries again.
    public event EventHandler<Exception>? Failed;

    public void Start()
    {
        if (_started)
        {
            return;
        }

        _started = true;
        _system.Responded += OnResponded;
        _store.Changed += OnStoreChanged;
        _system.Start();
        Refresh();
    }

    public void Refresh() => Request(force: true);

    // The bell of the footer: one test toast, five seconds from now. A second press replaces the first.
    public void SendTestAlert()
    {
        Refresh();
        if (Authorization != AlertAuthorization.Authorized)
        {
            return;
        }

        Guarded(() => _system.Schedule(AlertRequest.Test(FireTime(TestDelay), _texts)));
    }

    // Open shows the priority unless it is done or gone. Snooze adds a row 15 minutes ahead.
    public void Answer(AlertResponse response)
    {
        if (response.PriorityId is null)
        {
            AnswerTestAlert(response.Action);
            return;
        }

        if (_store.Find(response.PriorityId) is not { IsDone: false } priority)
        {
            return;
        }

        switch (response.Action)
        {
            case AlertAction.Open:
                OpenRequested?.Invoke(this, new AlertOpenRequest(priority.Id));
                break;
            case AlertAction.Snooze:
                Guarded(() => Snooze(priority, response.AlertId));
                break;
        }
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        _store.Changed -= OnStoreChanged;
        _system.Responded -= OnResponded;
        _wakeTimer?.Dispose();
        _wakeTimer = null;
    }

    private void OnStoreChanged(object? sender, EventArgs e) => Request(force: false);

    private void OnResponded(object? sender, AlertResponse response) => Answer(response);

    private void AnswerTestAlert(AlertAction action)
    {
        switch (action)
        {
            case AlertAction.Open:
                OpenRequested?.Invoke(this, new AlertOpenRequest(null));
                break;
            case AlertAction.Snooze:
                Guarded(() => _system.Schedule(AlertRequest.Test(FireTime(AlertPlanner.SnoozeTime), _texts)));
                break;
        }
    }

    private void Snooze(Priority priority, string actedAlertId)
    {
        if (priority.DueAt is null)
        {
            return;
        }

        var rows = new List<PriorityAlert>
        {
            new(Guid.NewGuid().ToString(), priority.Id, AlertKind.Snooze, FireTime(AlertPlanner.SnoozeTime), AlertStatus.Scheduled),
        };
        if (_store.Alert(actedAlertId) is { } acted)
        {
            rows.Add(acted with { Status = AlertStatus.Snoozed });
        }

        _store.SaveAlerts(rows);
        Refresh();
    }

    private DateTime FireTime(TimeSpan delay) => LocalTime.Now(_time) + delay;

    // A change that arrives while a run is going (the run saves rows itself) makes the run go round once more.
    private void Request(bool force)
    {
        _generation++;
        _forced |= force;
        if (_running)
        {
            return;
        }

        _running = true;
        try
        {
            while (true)
            {
                var seen = _generation;
                if (!Reconcile() || seen == _generation)
                {
                    break;
                }
            }
        }
        finally
        {
            _running = false;
        }
    }

    // False when a call failed. The failed run is not repeated at once: the next trigger retries.
    private bool Reconcile()
    {
        try
        {
            var subjects = _store.Snapshot.Open
                .Where(priority => priority.DueAt is not null)
                .Select(priority => new AlertSubject(priority.Id, priority.Title, priority.DueAt!.Value))
                .ToList();
            if (!_forced && _lastSubjects is { } last && last.SequenceEqual(subjects))
            {
                return true;
            }

            _forced = false;
            _lastSubjects = subjects;

            var authorization = _system.Authorization;
            SetAuthorization(authorization);
            var pending = _system.Pending();
            var delivered = _system.DeliveredIds().ToHashSet();
            var now = LocalTime.Now(_time);

            var plan = AlertReconciler.Plan(
                _store.Snapshot.Open,
                _store.Alerts(AlertStatus.Scheduled),
                pending,
                authorization,
                now,
                _texts);
            _store.SaveAlerts(plan.Save);
            ScheduleWake(plan.NextFireAt);

            if (plan.RemovePending.Count > 0)
            {
                _system.RemovePending(plan.RemovePending);
            }

            if (plan.RemoveDelivered.Count > 0)
            {
                _system.RemoveDelivered(plan.RemoveDelivered);
            }

            foreach (var request in plan.Add)
            {
                if (delivered.Contains(request.Id) && request.FireAt - now <= ShownAtOnce)
                {
                    continue;
                }

                _system.Schedule(request);
            }

            return true;
        }
        catch (Exception error) when (error is StoreException or AlertSystemException)
        {
            _lastSubjects = null;
            Failed?.Invoke(this, error);
            return false;
        }
    }

    private void SetAuthorization(AlertAuthorization authorization)
    {
        if (authorization == Authorization)
        {
            return;
        }

        Authorization = authorization;
        AuthorizationChanged?.Invoke(this, EventArgs.Empty);
    }

    private void ScheduleWake(DateTime? fireAt)
    {
        if (fireAt == _wakeAt)
        {
            return;
        }

        _wakeAt = fireAt;
        _wakeToken++;
        _wakeTimer?.Dispose();
        _wakeTimer = null;
        if (fireAt is not { } at)
        {
            return;
        }

        var token = _wakeToken;
        var untilFire = at - LocalTime.Now(_time);
        var wait = (untilFire > TimeSpan.Zero ? untilFire : TimeSpan.Zero) + WakeMargin;
        if (wait > WakeLimit)
        {
            wait = WakeLimit;
        }

        _wakeTimer = _time.CreateTimer(_ => Post(() => Wake(token)), null, wait, Timeout.InfiniteTimeSpan);
    }

    private void Wake(int token)
    {
        if (_disposed || token != _wakeToken)
        {
            return;
        }

        _wakeAt = null;
        Refresh();
    }

    private void Post(Action work)
    {
        if (_context is { } context)
        {
            context.Post(_ => work(), null);
        }
        else
        {
            work();
        }
    }

    private void Guarded(Action work)
    {
        try
        {
            work();
        }
        catch (Exception error) when (error is StoreException or AlertSystemException)
        {
            Failed?.Invoke(this, error);
        }
    }

    private sealed record AlertSubject(string Id, string Title, DateTime DueAt);
}
