using DailyZGT.Core.Domain;

namespace DailyZGT.Core.App;

// The one clock of the UI models (F12, F19, F21). Every delay of a model goes through After or Every, and
// every callback runs on the UI thread: TimeProvider timers fire on the thread pool, so the clock posts them
// to the UI context. With no context (tests on FakeTimeProvider) the callback runs where the timer fired.
public sealed class UiClock : IDisposable
{
    private static readonly TimeSpan Minute = TimeSpan.FromMinutes(1);

    private readonly TimeProvider _time;
    private readonly SynchronizationContext? _uiThread;
    private readonly ITimer _minuteTimer;
    private DateTime _day;
    private bool _disposed;

    public UiClock(TimeProvider time, SynchronizationContext? uiThread = null)
    {
        _time = time;
        _uiThread = uiThread;
        _day = Today;
        _minuteTimer = time.CreateTimer(_ => OnUiThread(OnMinute), null, UntilNextMinute(), Timeout.InfiniteTimeSpan);
    }

    public TimeProvider Time => _time;

    // Local wall-clock time, truncated to seconds, the same value the store writes.
    public DateTime Now => LocalTime.Now(_time);

    public DateTime Today => LocalTime.StartOfDay(Now);

    // Sub-second time for progress lines.
    public DateTimeOffset Instant => _time.GetUtcNow();

    // Raised at every local minute boundary: chips, the footer count and the Hechas window redraw (F12, F19, F21).
    public event EventHandler? MinuteTicked;

    // Raised when the local day differs from the last one seen, at a minute boundary or on CheckDay (F21).
    public event EventHandler? DayChanged;

    // The app calls this when it comes to the front or Windows reports a time change.
    public void CheckDay()
    {
        var today = Today;
        if (today == _day)
        {
            return;
        }
        _day = today;
        DayChanged?.Invoke(this, EventArgs.Empty);
    }

    public IDisposable After(TimeSpan delay, Action action) => new Scheduled(this, action, delay, Timeout.InfiniteTimeSpan);

    public IDisposable Every(TimeSpan period, Action action) => new Scheduled(this, action, period, period);

    public void Dispose()
    {
        _disposed = true;
        _minuteTimer.Dispose();
    }

    private void OnMinute()
    {
        if (_disposed)
        {
            return;
        }
        _minuteTimer.Change(UntilNextMinute(), Timeout.InfiniteTimeSpan);
        MinuteTicked?.Invoke(this, EventArgs.Empty);
        CheckDay();
    }

    private TimeSpan UntilNextMinute()
    {
        var now = _time.GetLocalNow();
        return Minute - TimeSpan.FromTicks(now.Ticks % Minute.Ticks);
    }

    private void OnUiThread(Action action)
    {
        if (_uiThread is null)
        {
            action();
        }
        else
        {
            _uiThread.Post(_ => action(), null);
        }
    }

    // A disposed handle also drops a callback that was already posted to the UI thread.
    private sealed class Scheduled : IDisposable
    {
        private readonly ITimer _timer;
        private bool _cancelled;

        public Scheduled(UiClock clock, Action action, TimeSpan due, TimeSpan period)
        {
            _timer = clock._time.CreateTimer(_ => clock.OnUiThread(() =>
            {
                if (!_cancelled)
                {
                    action();
                }
            }), null, due, period);
        }

        public void Dispose()
        {
            _cancelled = true;
            _timer.Dispose();
        }
    }
}
