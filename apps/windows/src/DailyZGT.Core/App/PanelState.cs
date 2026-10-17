using DailyZGT.Core.Domain;
using DailyZGT.Core.Store;

namespace DailyZGT.Core.App;

// F02. What fills the panel above the footer. Browse is the tabs with the list or the note. The detail view,
// the history and the settings replace it, so at most one of them is open.
public abstract record PanelPage
{
    private PanelPage()
    {
    }

    public sealed record Browse : PanelPage;

    public sealed record Detail(PriorityDetailModel Model) : PanelPage;

    public sealed record History : PanelPage;

    public sealed record Settings : PanelPage;
}

public enum PanelContentSlot { Main, UndoBar }

public static class PanelContentSlots
{
    private static readonly IReadOnlyList<PanelContentSlot> UndoBarBelow = [PanelContentSlot.Main, PanelContentSlot.UndoBar];
    private static readonly IReadOnlyList<PanelContentSlot> UndoBarAbove = [PanelContentSlot.UndoBar, PanelContentSlot.Main];

    // F07. The undo bar sits under the list and above the note. The view keeps one bar element in both
    // orders, so a tab switch moves the bar and does not replay its entry.
    public static IReadOnlyList<PanelContentSlot> Order(PanelTab tab) =>
        tab == PanelTab.Priorities ? UndoBarBelow : UndoBarAbove;
}

public static class PriorityListScopes
{
    // F02. The list picked in Prioridades decides which note Notas shows.
    public static NoteScope NoteScope(this PriorityList list) =>
        list == PriorityList.Today ? Domain.NoteScope.Day : Domain.NoteScope.Week;
}

// F02, F07, F08, F09, F16, F18. The root model of the panel: the tab and the list (kept in app_state), the
// open page, and the rules for what closes what. It owns the list actions, the note and the form, and the
// view calls OnActivated, OnDeactivated and OnQuit from the window events.
public sealed class PanelState : ObservableModel, IDisposable
{
    private readonly AppStore _store;
    private readonly UiClock _clock;
    private PanelTab _tab;
    private PriorityList _scope;
    private bool _isDoneOpen;
    private PanelPage _page = new PanelPage.Browse();
    private bool _saveFailed;

    public PanelState(AppStore store, UiClock clock, MotionPolicy motion, StartupSettings startup, ShortcutSettings shortcut)
    {
        _store = store;
        _clock = clock;
        _tab = store.Value(AppStateKeys.OpenTab);
        _scope = store.Value(AppStateKeys.OpenScope);
        _isDoneOpen = store.Value(AppStateKeys.DoneOpen);
        Startup = startup;
        Shortcut = shortcut;
        Flow = new PriorityFlow(store, clock, motion);
        Notes = new NotesModel(store, clock, _scope.NoteScope());
        Form = new NewPriorityForm(store, Flow, clock, _scope);
        Flow.PropertyChanged += OnFlowChanged;
        store.Changed += OnStoreChanged;
    }

    // The views read the rows from the store and redraw their chips on the clock.
    public AppStore Store => _store;

    public UiClock Clock => _clock;

    public PriorityFlow Flow { get; }

    public NotesModel Notes { get; }

    public NewPriorityForm Form { get; }

    public StartupSettings Startup { get; }

    public ShortcutSettings Shortcut { get; }

    public PanelTab Tab
    {
        get => _tab;
        private set
        {
            if (Set(ref _tab, value))
            {
                Raise(nameof(ContentSlots));
            }
        }
    }

    public PriorityList Scope
    {
        get => _scope;
        private set => Set(ref _scope, value);
    }

    // F08. Hechas starts closed and is kept across launches.
    public bool IsDoneOpen
    {
        get => _isDoneOpen;
        private set => Set(ref _isDoneOpen, value);
    }

    public PanelPage Page
    {
        get => _page;
        private set
        {
            if (Set(ref _page, value))
            {
                Raise(nameof(Detail), nameof(UndoBarVisible));
            }
        }
    }

    public PriorityDetailModel? Detail => (Page as PanelPage.Detail)?.Model;

    // F07. The bar shows on both tabs and in the detail view. It hides while the settings or the history are
    // open, and its 5 s keep running.
    public bool UndoBarVisible => Flow.Undo is not null && Page is PanelPage.Browse or PanelPage.Detail;

    public IReadOnlyList<PanelContentSlot> ContentSlots => PanelContentSlots.Order(Tab);

    // A write of the tab, the list, Hechas or a setting failed.
    public bool SaveFailed
    {
        get => _saveFailed;
        private set => Set(ref _saveFailed, value);
    }

    // F06. "Máximo 5 prioridades abiertas en Hoy".
    public bool TodayLimitIsOn
    {
        get => _store.Value(AppStateKeys.TodayLimit);
        set => Persist(AppStateKeys.TodayLimit, value);
    }

    // F01. "Siguiente prioridad en la barra de tareas".
    public bool TrayTitleIsOn
    {
        get => _store.Value(AppStateKeys.TrayTitle);
        set => Persist(AppStateKeys.TrayTitle, value);
    }

    // A tab click also closes the detail view, the history and the settings, on the same tab too.
    public void SelectTab(PanelTab tab)
    {
        ShowPage(new PanelPage.Browse());
        if (tab == Tab)
        {
            return;
        }
        if (Tab == PanelTab.Notes)
        {
            Notes.Flush();
        }
        Tab = tab;
        Persist(AppStateKeys.OpenTab, tab);
    }

    // The detail view stays open: a move from the Lista row selects the new list.
    public void SelectScope(PriorityList scope)
    {
        if (scope == Scope)
        {
            return;
        }
        if (Page is PanelPage.History)
        {
            ShowPage(new PanelPage.Browse());
        }
        Scope = scope;
        Notes.SelectScope(scope.NoteScope());
        Form.List = scope;
        Persist(AppStateKeys.OpenScope, scope);
    }

    // F09. A done or missing priority opens nothing.
    public void OpenDetail(string id)
    {
        if (_store.Find(id) is not { IsDone: false } priority)
        {
            return;
        }
        Flow.CancelConfirmation();
        SelectTab(PanelTab.Priorities);
        SelectScope(priority.List);
        ShowPage(new PanelPage.Detail(new PriorityDetailModel(_store, _clock, priority, SelectScope)));
    }

    public void CloseDetail()
    {
        if (Page is PanelPage.Detail)
        {
            ShowPage(new PanelPage.Browse());
        }
    }

    // F18. Opening the settings reads the system state again and saves the note.
    public void OpenSettings()
    {
        if (Page is PanelPage.Settings)
        {
            return;
        }
        ShowPage(new PanelPage.Settings());
        Notes.Flush();
        Startup.SettingsDidOpen();
        Shortcut.SettingsDidOpen();
    }

    public void CloseSettings()
    {
        if (Page is PanelPage.Settings)
        {
            ShowPage(new PanelPage.Browse());
        }
    }

    // The gear: it opens the settings from any page, and closes them.
    public void ToggleSettings()
    {
        if (Page is PanelPage.Settings)
        {
            CloseSettings();
        }
        else
        {
            OpenSettings();
        }
    }

    public void OpenHistory()
    {
        if (Page is PanelPage.History)
        {
            return;
        }
        SelectTab(PanelTab.Priorities);
        ShowPage(new PanelPage.History());
    }

    public void CloseHistory()
    {
        if (Page is PanelPage.History)
        {
            ShowPage(new PanelPage.Browse());
        }
    }

    public void ToggleDone()
    {
        IsDoneOpen = !IsDoneOpen;
        Persist(AppStateKeys.DoneOpen, IsDoneOpen);
    }

    // F15. "Abrir" on an alert: the list of the priority, scrolled to it and flashed. A done or missing
    // priority, or the test alert, shows Hoy and flashes nothing.
    public void ShowInList(string? id)
    {
        var priority = id is null ? null : _store.Find(id);
        var open = priority is { IsDone: false } ? priority : null;
        SelectTab(PanelTab.Priorities);
        SelectScope(open?.List ?? PriorityList.Today);
        if (open is not null)
        {
            Flow.Flash(open.Id);
        }
    }

    // The panel got the focus (F16, F18, F21).
    public void OnActivated()
    {
        _clock.CheckDay();
        Notes.Sync();
        Detail?.Note.Sync();
        Startup.Refresh();
    }

    // The panel lost the focus (F11, F16).
    public void OnDeactivated()
    {
        Notes.Flush();
        Detail?.Note.Flush();
    }

    // "Salir" (F16).
    public void OnQuit() => OnDeactivated();

    public void Dispose()
    {
        _store.Changed -= OnStoreChanged;
        Flow.PropertyChanged -= OnFlowChanged;
        Detail?.Dispose();
        Notes.Dispose();
        Flow.Dispose();
    }

    // Closing a detail view cancels the open confirmation and saves its note (F07, F11).
    private void ShowPage(PanelPage next)
    {
        var previous = Page;
        if (previous == next)
        {
            return;
        }
        Page = next;
        if (previous is PanelPage.Detail closed)
        {
            Flow.CancelConfirmation();
            closed.Model.Dispose();
        }
    }

    // F09. The detail view closes when its priority is deleted or done from elsewhere.
    private void OnStoreChanged(object? sender, EventArgs e)
    {
        if (Detail is { } detail)
        {
            if (_store.Find(detail.Id) is { IsDone: false })
            {
                detail.Refresh();
            }
            else
            {
                CloseDetail();
            }
        }
        Notes.Sync();
        Form.Refresh();
        Raise(nameof(TodayLimitIsOn), nameof(TrayTitleIsOn));
    }

    private void OnFlowChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(PriorityFlow.Undo))
        {
            Raise(nameof(UndoBarVisible));
        }
    }

    private void Persist<T>(AppStateKey<T> key, T value)
    {
        try
        {
            _store.SetValue(key, value);
            SaveFailed = false;
        }
        catch (StoreException)
        {
            SaveFailed = true;
        }
    }
}
