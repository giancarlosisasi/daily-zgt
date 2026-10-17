using DailyZGT.Core.Alerts;
using DailyZGT.Core.App;
using DailyZGT.Core.Domain;
using DailyZGT.Core.Localization;
using DailyZGT.Core.Store;
using DailyZGT.Shell;
using Microsoft.Extensions.Time.Testing;

namespace DailyZGT.Platform.Tests;

public sealed class ShellModelTests : IDisposable
{
    private readonly FakeTimeProvider time;
    private readonly AppStore store;
    private readonly UiClock clock;
    private readonly FakeAlerts alertSystem = new();
    private readonly AlertCoordinator alerts;
    private readonly PanelState panel;
    private readonly TraySummary tray;
    private readonly ShellModel shell;

    public ShellModelTests()
    {
        time = new FakeTimeProvider(new DateTimeOffset(2026, 10, 12, 23, 58, 30, TimeSpan.Zero));
        time.SetLocalTimeZone(TimeZoneInfo.Utc);
        store = AppStore.OpenInMemory(time);
        clock = new UiClock(time);
        alerts = new AlertCoordinator(store, alertSystem, Texts.Es, time);
        panel = new PanelState(
            store,
            clock,
            new MotionPolicy(new StillAnimations(), TimeSpan.Zero),
            new StartupSettings(new OffStartup()),
            new ShortcutSettings(new NoHotkey()));
        tray = new TraySummary(store);
        shell = new ShellModel(panel, store, clock, alerts, tray, Texts.Es);
    }

    [Fact]
    public void Scope_tabs_and_footer_count_follow_the_data()
    {
        store.AddPriority("Llamar a Marta", PriorityList.Today);
        var done = ((AddOutcome.Added)store.AddPriority("Pagar la renta", PriorityList.Today)).Priority;
        store.AddPriority("Revisar contrato", PriorityList.Week);
        store.MarkDone(done.Id);

        Assert.Equal("Hoy · 1", shell.TodayTab);
        Assert.Equal("Semana · 1", shell.WeekTab);
        Assert.Equal("1 de 2 hechas hoy", shell.FooterSummary);
    }

    [Fact]
    public void Date_and_footer_follow_the_open_list()
    {
        Assert.Equal("Lunes 12 oct", shell.Date);

        panel.SelectScope(PriorityList.Week);

        Assert.Equal("Semana 42 · 12–18 oct", shell.Date);
        Assert.Equal("0 de 0 hechas esta semana", shell.FooterSummary);
    }

    [Fact]
    public void The_date_turns_over_at_midnight_on_the_minute_tick()
    {
        time.Advance(TimeSpan.FromMinutes(2));

        Assert.Equal("Martes 13 oct", shell.Date);
    }

    [Fact]
    public void Tray_tooltip_has_the_next_priority_while_the_setting_is_on()
    {
        store.AddPriority("Enviar el informe trimestral del equipo", PriorityList.Today);

        Assert.Equal("Daily ZGT · 1\nEnviar el informe trime…", shell.TrayTooltip);

        panel.TrayTitleIsOn = false;

        Assert.Equal("Daily ZGT · 1", shell.TrayTooltip);
    }

    [Fact]
    public void The_bell_shows_alerts_off_when_Windows_blocks_the_toasts()
    {
        alertSystem.Authorization = AlertAuthorization.Denied;

        alerts.Start();

        Assert.True(shell.AlertsOff);
    }

    public void Dispose()
    {
        shell.Dispose();
        tray.Dispose();
        panel.Dispose();
        alerts.Dispose();
        clock.Dispose();
        store.Dispose();
    }

    private sealed class StillAnimations : IAnimationSource
    {
        public bool AnimationsEnabled => false;

        public event EventHandler? Changed
        {
            add { }
            remove { }
        }
    }

    private sealed class OffStartup : IStartupService
    {
        public StartupStatus State => StartupStatus.Off;

        public void Enable()
        {
        }

        public void Disable()
        {
        }
    }

    private sealed class NoHotkey : ICaptureHotkey
    {
        public CaptureShortcut? Current => null;

        public event EventHandler? Pressed
        {
            add { }
            remove { }
        }

        public ShortcutFailure? Start() => null;

        public void Set(CaptureShortcut shortcut)
        {
        }

        public void Clear()
        {
        }
    }

    private sealed class FakeAlerts : IAlertSystem
    {
        public AlertAuthorization Authorization { get; set; } = AlertAuthorization.Authorized;

        public event EventHandler<AlertResponse>? Responded
        {
            add { }
            remove { }
        }

        public void Start()
        {
        }

        public IReadOnlyList<AlertRequest> Pending() => [];

        public IReadOnlyList<string> DeliveredIds() => [];

        public void Schedule(AlertRequest request)
        {
        }

        public void RemovePending(IEnumerable<string> ids)
        {
        }

        public void RemoveDelivered(IEnumerable<string> ids)
        {
        }
    }
}
