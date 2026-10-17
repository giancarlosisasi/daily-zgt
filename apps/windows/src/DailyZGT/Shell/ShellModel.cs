using System.ComponentModel;
using DailyZGT.Core.Alerts;
using DailyZGT.Core.App;
using DailyZGT.Core.Domain;
using DailyZGT.Core.Localization;
using DailyZGT.Core.Rules;
using DailyZGT.Core.Store;

namespace DailyZGT.Shell;

// F01, F02, F15, F19. The words of the shell that the Core models leave to the view: the scope tabs with
// their counts, the date, the footer count, the tray tooltip, and whether the alerts are off. They follow
// every change of the data, of the list, of the alert setting and of the minute.
public sealed class ShellModel : ObservableModel, IDisposable
{
    private readonly AppStore _store;
    private readonly UiClock _clock;
    private readonly AlertCoordinator _alerts;
    private readonly TraySummary _tray;
    private readonly Texts _texts;
    private string _todayTab = "";
    private string _weekTab = "";
    private string _date = "";
    private string _footer = "";
    private string _trayTooltip = "";
    private bool _alertsOff;

    public ShellModel(PanelState panel, AppStore store, UiClock clock, AlertCoordinator alerts, TraySummary tray, Texts texts)
    {
        Panel = panel;
        _store = store;
        _clock = clock;
        _alerts = alerts;
        _tray = tray;
        _texts = texts;
        store.Changed += OnChanged;
        clock.MinuteTicked += OnChanged;
        clock.DayChanged += OnChanged;
        alerts.AuthorizationChanged += OnChanged;
        tray.PropertyChanged += OnTrayChanged;
        panel.PropertyChanged += OnPanelChanged;
        Refresh();
    }

    public PanelState Panel { get; }

    public TraySummary Tray => _tray;

    // `Hoy · 3`.
    public string TodayTab
    {
        get => _todayTab;
        private set => Set(ref _todayTab, value);
    }

    // `Semana · 5`.
    public string WeekTab
    {
        get => _weekTab;
        private set => Set(ref _weekTab, value);
    }

    // `Lunes 12 oct` or `Semana 42 · 12–18 oct`, for the open list.
    public string Date
    {
        get => _date;
        private set => Set(ref _date, value);
    }

    // `1 de 5 hechas hoy`, for the open list.
    public string FooterSummary
    {
        get => _footer;
        private set => Set(ref _footer, value);
    }

    // `Daily ZGT · 3`, and the next priority on a second line when the setting is on.
    public string TrayTooltip
    {
        get => _trayTooltip;
        private set => Set(ref _trayTooltip, value);
    }

    public bool AlertsOff
    {
        get => _alertsOff;
        private set => Set(ref _alertsOff, value);
    }

    public void Refresh()
    {
        var scope = Panel.Scope;
        var now = _clock.Now;
        TodayTab = PanelLabels.ScopeTab(PriorityList.Today, _store.OpenCount(PriorityList.Today), _texts);
        WeekTab = PanelLabels.ScopeTab(PriorityList.Week, _store.OpenCount(PriorityList.Week), _texts);
        Date = PanelLabels.Date(scope, now, _texts);
        FooterSummary = PanelLabels.Summary(scope, _store.Snapshot, now, _texts);
        TrayTooltip = _texts.TrayTooltip(_tray.Count ?? 0) + (_tray.Title is { } title ? "\n" + title : "");
        AlertsOff = _alerts.AlertsAreOff;
    }

    public void Dispose()
    {
        _store.Changed -= OnChanged;
        _clock.MinuteTicked -= OnChanged;
        _clock.DayChanged -= OnChanged;
        _alerts.AuthorizationChanged -= OnChanged;
        _tray.PropertyChanged -= OnTrayChanged;
        Panel.PropertyChanged -= OnPanelChanged;
    }

    private void OnChanged(object? sender, EventArgs e) => Refresh();

    private void OnTrayChanged(object? sender, PropertyChangedEventArgs e) => Refresh();

    private void OnPanelChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(PanelState.Scope))
        {
            Refresh();
        }
    }
}
