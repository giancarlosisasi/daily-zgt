using DailyZGT.Core.App;
using DailyZGT.Core.Domain;
using DailyZGT.Core.Store;
using DailyZGT.Core.Tests.Support;
using Microsoft.Extensions.Time.Testing;

namespace DailyZGT.Core.Tests.App;

// A store on a temp file and a UiClock on a FakeTimeProvider in UTC, so the local wall-clock time is the
// text the test writes and Advance fires the timers of the models in order.
public sealed class AppHarness : IDisposable
{
    public static readonly TimeSpan RowLeave = TimeSpan.FromMilliseconds(320);

    private readonly List<IDisposable> _owned = [];

    public AppHarness(string start = "2026-10-12T10:24:00")
    {
        FakeTime = new FakeTimeProvider(new DateTimeOffset(DateTime.SpecifyKind(Time.At(start), DateTimeKind.Unspecified), TimeSpan.Zero));
        FakeTime.SetLocalTimeZone(TimeZoneInfo.Utc);
        Clock = new UiClock(FakeTime);
        Folder = TempFolder.Create();
        FilePath = Path.Combine(Folder, AppDatabase.FileName);
        Store = AppStore.OpenFile(FilePath, FakeTime);
        Animations = new FakeAnimationSource();
        Motion = new MotionPolicy(Animations, RowLeave);
        StartupService = new FakeStartupService();
        Hotkey = new FakeHotkey();
    }

    public FakeTimeProvider FakeTime { get; }

    public UiClock Clock { get; }

    public string Folder { get; }

    public string FilePath { get; }

    public AppStore Store { get; }

    public FakeAnimationSource Animations { get; }

    public MotionPolicy Motion { get; }

    public FakeStartupService StartupService { get; }

    public FakeHotkey Hotkey { get; }

    public DateTime Now => Clock.Now;

    public void Advance(TimeSpan time) => FakeTime.Advance(time);

    public void AdvanceMs(int milliseconds) => FakeTime.Advance(TimeSpan.FromMilliseconds(milliseconds));

    public void Set(string localTime) =>
        FakeTime.SetUtcNow(new DateTimeOffset(DateTime.SpecifyKind(Time.At(localTime), DateTimeKind.Unspecified), TimeSpan.Zero));

    public PriorityFlow Flow() => Own(new PriorityFlow(Store, Clock, Motion));

    public PanelState Panel() => Panel(Store);

    public PanelState Panel(AppStore store) =>
        Own(new PanelState(store, Clock, Motion, new StartupSettings(StartupService), new ShortcutSettings(Hotkey)));

    public AppStore OpenAnotherStore() => Own(AppStore.OpenFile(FilePath, FakeTime));

    public void TurnOnTodayLimit() => Store.SetValue(AppStateKeys.TodayLimit, true);

    public List<Priority> Fill(int open, PriorityList list = PriorityList.Today) =>
        Enumerable.Range(0, open).Select(index => Store.Add($"Open {index}", list)).ToList();

    public List<T> Rows<T>(string sql) => OutsideConnection.Rows<T>(FilePath, sql);

    public void Execute(string sql) => OutsideConnection.Execute(FilePath, sql);

    public T Own<T>(T disposable) where T : IDisposable
    {
        _owned.Add(disposable);
        return disposable;
    }

    public void Dispose()
    {
        foreach (var owned in Enumerable.Reverse(_owned))
        {
            owned.Dispose();
        }
        Store.Dispose();
        Clock.Dispose();
        TempFolder.Delete(Folder);
    }
}

public sealed class FakeAnimationSource : IAnimationSource
{
    public bool AnimationsEnabled { get; private set; } = true;

    public event EventHandler? Changed;

    public void Set(bool enabled)
    {
        AnimationsEnabled = enabled;
        Changed?.Invoke(this, EventArgs.Empty);
    }
}

public sealed class FakeStartupService : IStartupService
{
    public StartupStatus State { get; set; } = StartupStatus.Off;

    public StartupStatus StateAfterEnable { get; set; } = StartupStatus.On;

    public bool EnableFails { get; set; }

    public bool DisableFails { get; set; }

    public int EnableCalls { get; private set; }

    public int DisableCalls { get; private set; }

    public void Enable()
    {
        EnableCalls++;
        if (EnableFails)
        {
            throw new StartupChangeException("Windows did not accept the change.");
        }
        State = StateAfterEnable;
    }

    public void Disable()
    {
        DisableCalls++;
        if (DisableFails)
        {
            throw new StartupChangeException("Windows did not accept the change.");
        }
        State = StartupStatus.Off;
    }
}

public sealed class FakeHotkey : ICaptureHotkey
{
    public static readonly CaptureShortcut Default =
        new(ShortcutModifiers.Control | ShortcutModifiers.Alt | ShortcutModifiers.Shift, 'P');

    public CaptureShortcut? Current { get; set; } = Default;

    public ShortcutFailure? StartFailure { get; set; }

    public ShortcutFailure? SetFailure { get; set; }

    public int StartCalls { get; private set; }

    public event EventHandler? Pressed;

    public ShortcutFailure? Start()
    {
        StartCalls++;
        return StartFailure;
    }

    public void Set(CaptureShortcut shortcut)
    {
        if (SetFailure is { } failure)
        {
            throw new ShortcutChangeException(failure, "Rejected.");
        }
        Current = shortcut;
    }

    public void Clear() => Current = null;

    public void Press() => Pressed?.Invoke(this, EventArgs.Empty);

    public int Subscribers => Pressed?.GetInvocationList().Length ?? 0;
}
