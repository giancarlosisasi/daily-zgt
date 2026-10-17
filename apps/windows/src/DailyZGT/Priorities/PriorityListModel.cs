using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Windows.Input;
using DailyZGT.Core.App;
using DailyZGT.Core.Domain;
using DailyZGT.Core.Localization;
using DailyZGT.Core.Rules;

namespace DailyZGT.Priorities;

// F03. What fills the list when it has no open priority.
public enum EmptyList { None, AllDone, NothingPending }

// F03 to F08, F12, F13. The rows of the open list, its empty state and the Hechas section of the list the
// panel shows. It redraws after every change of the data, of the flow, of the list and at each minute.
public sealed class PriorityListModel : ObservableModel, IDisposable
{
    private readonly Texts _texts = UiText.Current;
    private IReadOnlyDictionary<string, IReadOnlyList<PriorityEvent>> _entering = new Dictionary<string, IReadOnlyList<PriorityEvent>>();
    private bool _enteringIsStale = true;
    private bool _drawn;
    private EmptyList _empty;
    private string _doneHeader = "";
    private bool _showsDone;
    private int _historyCount;
    private IReadOnlyList<DoneRowItem> _doneRows = [];

    public PriorityListModel(PanelState panel)
    {
        Panel = panel;
        ToggleDoneSection = new RelayCommand(panel.ToggleDone);
        OpenHistory = new RelayCommand(panel.OpenHistory);
        OpenForm = new RelayCommand(panel.Form.Open);
        CancelForm = new RelayCommand(panel.Form.Cancel);
        SubmitForm = new RelayCommand(panel.Form.Submit);
        panel.PropertyChanged += OnPanelChanged;
        panel.Flow.PropertyChanged += OnFlowChanged;
        panel.Store.Changed += OnStoreChanged;
        panel.Clock.MinuteTicked += OnMinute;
        Refresh();
    }

    public PanelState Panel { get; }

    public NewPriorityForm Form => Panel.Form;

    public PriorityFlow Flow => Panel.Flow;

    public ICommand ToggleDoneSection { get; }

    public ICommand OpenHistory { get; }

    public ICommand OpenForm { get; }

    public ICommand CancelForm { get; }

    public ICommand SubmitForm { get; }

    public ObservableCollection<OpenRowItem> Rows { get; } = [];

    public EmptyList Empty
    {
        get => _empty;
        private set
        {
            if (Set(ref _empty, value))
            {
                Raise(nameof(HasRows), nameof(IsAllDone), nameof(IsNothingPending));
            }
        }
    }

    public bool HasRows => Empty == EmptyList.None;

    public bool IsAllDone => Empty == EmptyList.AllDone;

    public bool IsNothingPending => Empty == EmptyList.NothingPending;

    // F08. The section shows while the list has any done priority, also when all are older than 24 hours.
    public bool ShowsDone
    {
        get => _showsDone;
        private set => Set(ref _showsDone, value);
    }

    public string DoneHeader
    {
        get => _doneHeader;
        private set => Set(ref _doneHeader, value);
    }

    public bool IsDoneOpen => Panel.IsDoneOpen;

    public string DoneState => IsDoneOpen ? _texts.StateExpanded : _texts.StateCollapsed;

    public IReadOnlyList<DoneRowItem> DoneRows
    {
        get => _doneRows;
        private set => Set(ref _doneRows, value);
    }

    public int HistoryCount
    {
        get => _historyCount;
        private set
        {
            if (Set(ref _historyCount, value))
            {
                Raise(nameof(ShowsHistoryRow));
            }
        }
    }

    public bool ShowsHistoryRow => IsDoneOpen && HistoryCount > 0;

    public void Refresh()
    {
        var store = Panel.Store;
        var list = Panel.Scope;
        var now = Panel.Clock.Now;
        if (_enteringIsStale)
        {
            _entering = list == PriorityList.Today ? store.EnteringEvents(list) : new Dictionary<string, IReadOnlyList<PriorityEvent>>();
            _enteringIsStale = false;
        }

        var open = store.OpenPriorities(list);
        var drawn = _drawn;
        Keyed.Sync(
            Rows,
            open,
            priority => priority.Id,
            row => row.Id,
            priority => new OpenRowItem(priority.Id, Panel, isNew: drawn),
            (row, priority) => row.Update(priority, store.Subtasks(priority.Id), EnteredToday(priority), now, Flow));
        _drawn = true;

        var done = store.DonePriorities(list);
        var recent = done.Where(priority => DoneWindow.IsRecent(priority.DoneAt!.Value, now)).ToList();
        Empty = open.Count > 0 ? EmptyList.None : recent.Count > 0 ? EmptyList.AllDone : EmptyList.NothingPending;
        ShowsDone = done.Count > 0;
        DoneHeader = _texts.DoneHeader(recent.Count);
        if (!DoneRows.Select(row => row.Id).SequenceEqual(recent.Select(priority => priority.Id))
            || !DoneRows.Select(row => row.Title).SequenceEqual(recent.Select(priority => priority.Title)))
        {
            DoneRows = recent.Select(priority => new DoneRowItem(priority, Flow)).ToList();
        }

        HistoryCount = done.Count - recent.Count;
    }

    public void Dispose()
    {
        Panel.PropertyChanged -= OnPanelChanged;
        Panel.Flow.PropertyChanged -= OnFlowChanged;
        Panel.Store.Changed -= OnStoreChanged;
        Panel.Clock.MinuteTicked -= OnMinute;
    }

    // F13. Semana never shows the chip.
    private DateTime? EnteredToday(Priority priority) =>
        Panel.Scope == PriorityList.Today && _entering.TryGetValue(priority.Id, out var events) ? TodayEntry.EnteredAt(events) : null;

    private void OnPanelChanged(object? sender, PropertyChangedEventArgs e)
    {
        switch (e.PropertyName)
        {
            case nameof(PanelState.Scope):
                _enteringIsStale = true;
                _drawn = false;
                Rows.Clear();
                Refresh();
                break;
            case nameof(PanelState.IsDoneOpen):
                Raise(nameof(IsDoneOpen), nameof(DoneState), nameof(ShowsHistoryRow));
                break;
        }
    }

    private void OnFlowChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(PriorityFlow.Undo) or nameof(PriorityFlow.ScrollTargetId))
        {
            return;
        }

        Refresh();
    }

    private void OnStoreChanged(object? sender, EventArgs e)
    {
        _enteringIsStale = true;
        Refresh();
    }

    private void OnMinute(object? sender, EventArgs e) => Refresh();
}
