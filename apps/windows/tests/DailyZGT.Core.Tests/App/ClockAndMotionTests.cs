using DailyZGT.Core.App;
using DailyZGT.Core.Tests.Support;
using Microsoft.Extensions.Time.Testing;

namespace DailyZGT.Core.Tests.App;

public sealed class UiClockTests : IDisposable
{
    private readonly FakeTimeProvider _time = new(new DateTimeOffset(2026, 10, 12, 10, 24, 30, TimeSpan.Zero));
    private readonly UiClock _clock;
    private readonly List<DateTime> _ticks = [];
    private int _days;

    public UiClockTests()
    {
        _time.SetLocalTimeZone(TimeZoneInfo.Utc);
        _clock = new UiClock(_time);
        _clock.MinuteTicked += (_, _) => _ticks.Add(_clock.Now);
        _clock.DayChanged += (_, _) => _days++;
    }

    public void Dispose() => _clock.Dispose();

    [Fact]
    public void NowIsTheLocalTimeTruncatedToSeconds()
    {
        _time.Advance(TimeSpan.FromMilliseconds(700));

        Assert.Equal(Time.At("2026-10-12T10:24:30"), _clock.Now);
        Assert.Equal(Time.At("2026-10-12T00:00:00"), _clock.Today);
    }

    [Fact]
    public void TheTickComesAtEveryMinuteBoundary()
    {
        _time.Advance(TimeSpan.FromSeconds(29));
        Assert.Empty(_ticks);

        _time.Advance(TimeSpan.FromSeconds(1));
        _time.Advance(TimeSpan.FromMinutes(1));
        _time.Advance(TimeSpan.FromMinutes(1));

        Assert.Equal([Time.At("2026-10-12T10:25:00"), Time.At("2026-10-12T10:26:00"), Time.At("2026-10-12T10:27:00")], _ticks);
    }

    [Fact]
    public void TheTickAtMidnightReportsTheNewDay()
    {
        _time.SetUtcNow(new DateTimeOffset(2026, 10, 12, 23, 59, 10, TimeSpan.Zero));
        _days = 0;

        _time.Advance(TimeSpan.FromSeconds(50));

        Assert.Equal(1, _days);
        Assert.Equal(Time.At("2026-10-13T00:00:00"), _clock.Today);
    }

    [Fact]
    public void CheckDayReportsANewDayOnce()
    {
        var clock = new TestClock("2026-10-12T22:00:00");
        using var still = new UiClock(clock);
        var days = 0;
        still.DayChanged += (_, _) => days++;

        still.CheckDay();
        clock.Set("2026-10-13T07:00:00");
        still.CheckDay();
        still.CheckDay();

        Assert.Equal(1, days);
    }

    [Fact]
    public void AfterRunsOnceAndADisposedHandleNeverRuns()
    {
        var runs = new List<string>();
        _clock.After(TimeSpan.FromMilliseconds(400), () => runs.Add("kept"));
        var dropped = _clock.After(TimeSpan.FromMilliseconds(400), () => runs.Add("dropped"));

        dropped.Dispose();
        _time.Advance(TimeSpan.FromSeconds(5));

        Assert.Equal(["kept"], runs);
    }

    [Fact]
    public void EveryRunsAtEachPeriodUntilDisposed()
    {
        var runs = 0;
        var every = _clock.Every(TimeSpan.FromSeconds(30), () => runs++);

        _time.Advance(TimeSpan.FromSeconds(30));
        _time.Advance(TimeSpan.FromSeconds(30));
        every.Dispose();
        _time.Advance(TimeSpan.FromSeconds(30));

        Assert.Equal(2, runs);
    }

    [Fact]
    public void WithAUiContextTheCallbacksArePostedToIt()
    {
        var context = new QueueContext();
        using var clock = new UiClock(_time, context);
        var runs = 0;
        var handle = clock.After(TimeSpan.FromSeconds(1), () => runs++);

        _time.Advance(TimeSpan.FromSeconds(1));
        Assert.Equal(0, runs);

        context.RunAll();
        Assert.Equal(1, runs);

        clock.After(TimeSpan.FromSeconds(1), () => runs++).Dispose();
        _time.Advance(TimeSpan.FromSeconds(1));
        handle.Dispose();
        context.RunAll();
        Assert.Equal(1, runs);
    }

    [Fact]
    public void ACallbackPostedBeforeTheHandleIsDisposedDoesNotRun()
    {
        var context = new QueueContext();
        using var clock = new UiClock(_time, context);
        var runs = 0;
        var handle = clock.After(TimeSpan.FromSeconds(1), () => runs++);
        _time.Advance(TimeSpan.FromSeconds(1));

        handle.Dispose();
        context.RunAll();

        Assert.Equal(0, runs);
    }

    private sealed class QueueContext : SynchronizationContext
    {
        private readonly Queue<(SendOrPostCallback Callback, object? State)> _queue = new();

        public override void Post(SendOrPostCallback d, object? state) => _queue.Enqueue((d, state));

        public void RunAll()
        {
            while (_queue.TryDequeue(out var item))
            {
                item.Callback(item.State);
            }
        }
    }
}

public sealed class MotionPolicyTests
{
    private readonly FakeAnimationSource _source = new();

    [Fact]
    public void WithAnimationsOnTheRowLeavesAfterTheSlowDuration()
    {
        using var policy = new MotionPolicy(_source, AppHarness.RowLeave);

        Assert.False(policy.IsReduced);
        Assert.True(policy.Animates);
        Assert.Equal(TimeSpan.FromMilliseconds(320), policy.LeaveDelay);
    }

    [Fact]
    public void WithAnimationsOffTheRowLeavesAtOnce()
    {
        _source.Set(enabled: false);
        using var policy = new MotionPolicy(_source, AppHarness.RowLeave);

        Assert.True(policy.IsReduced);
        Assert.False(policy.Animates);
        Assert.Equal(TimeSpan.Zero, policy.LeaveDelay);
    }

    [Fact]
    public void TheWindowsSettingIsFollowedWhileTheAppRuns()
    {
        using var policy = new MotionPolicy(_source, AppHarness.RowLeave);
        var raised = new List<string?>();
        policy.PropertyChanged += (_, e) => raised.Add(e.PropertyName);

        _source.Set(enabled: false);

        Assert.True(policy.IsReduced);
        Assert.Equal([nameof(MotionPolicy.IsReduced), nameof(MotionPolicy.Animates), nameof(MotionPolicy.LeaveDelay)], raised);

        policy.Dispose();
        _source.Set(enabled: true);
        Assert.True(policy.IsReduced);
    }
}
