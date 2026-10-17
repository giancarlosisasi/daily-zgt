using System.ComponentModel;
using System.Windows.Input;
using DailyZGT.Core.App;
using DailyZGT.Core.Domain;
using DailyZGT.Core.Localization;
using DailyZGT.Core.Rules;

namespace DailyZGT.Priorities;

// F09 to F14. What the detail view draws for the open PriorityDetailModel: the labels and chips the model
// does not carry, and the keys of the box written back through the model.
public sealed class DetailItem : ObservableModel, IDisposable
{
    private readonly Texts _texts = UiText.Current;
    private readonly PanelState _panel;
    private DateTime? _enteredToday;
    private bool _enteredIsStale = true;

    public DetailItem(PanelState panel, PriorityDetailModel model)
    {
        _panel = panel;
        Model = model;
        Subtasks = new SubtaskListItem(model.Subtasks);
        Back = new RelayCommand(panel.CloseDetail);
        Delete = new RelayCommand(() => panel.Flow.Delete(model.Id));
        MarkDone = new RelayCommand(() => panel.Flow.ToggleConfirmation(model.Id));
        CancelDone = new RelayCommand(panel.Flow.CancelConfirmation);
        ConfirmDone = new RelayCommand(() => panel.Flow.ConfirmDone(model.Id, DoneOrigin.Detail));
        model.PropertyChanged += OnChanged;
        panel.Flow.PropertyChanged += OnChanged;
        panel.Store.Changed += OnStoreChanged;
        panel.Clock.MinuteTicked += OnMinute;
        Subtasks.Update(panel.Store.Subtasks(model.Id));
    }

    public PriorityDetailModel Model { get; }

    public PriorityNoteModel Note => Model.Note;

    public SubtaskListItem Subtasks { get; }

    public UiClock Clock => _panel.Clock;

    public ICommand Back { get; }

    public ICommand Delete { get; }

    public ICommand MarkDone { get; }

    public ICommand CancelDone { get; }

    public ICommand ConfirmDone { get; }

    private Priority Priority => Model.Priority;

    private DateTime Now => _panel.Clock.Now;

    private SubtaskProgress Progress => SubtaskProgress.Of(_panel.Store.Subtasks(Model.Id));

    // F09. "‹ Hoy" names the list of the priority.
    public string BackLabel => Priority.List.Title(_texts);

    public string BackName => _texts.BackTo(BackLabel);

    public string StateLabel => PriorityDetailLabels.State(Priority, _texts);

    public DueChip? Due => DueChip.Make(Priority.DueAt, Now, _texts);

    public DueChip? Since => TodayEntryChip.Make(EnteredToday, Now, _texts);

    public string? SubtasksChip => PriorityDetailLabels.Subtasks(Progress, _texts);

    public PriorityLevel Level
    {
        get => Priority.Level;
        set => Model.SetLevel(value);
    }

    public PriorityList List
    {
        get => Priority.List;
        set => Model.SetList(value);
    }

    public RepeatRule Repeat
    {
        get => Priority.RepeatRule;
        set => Model.SetRepeat(value);
    }

    public DateTime? DueAt => Priority.DueAt;

    public bool HasDue => Priority.DueAt is not null;

    public string AlertText => PriorityDetailLabels.Alert(Priority.DueAt, _texts);

    public bool IsConfirming => _panel.Flow.ConfirmingId == Model.Id;

    public DetailItem? Confirmation => IsConfirming ? this : null;

    public string? OpenSubtasksHint => Progress.OpenSubtasksLabel(_texts);

    public string Created => PriorityDetailLabels.Created(Priority.CreatedAt, Now, _texts);

    public bool SaveFailed => Model.SaveFailed || _panel.Flow.SaveFailed;

    // F13. Semana never shows the chip.
    private DateTime? EnteredToday
    {
        get
        {
            if (_enteredIsStale)
            {
                _enteredToday = Priority.List == PriorityList.Today ? TodayEntry.EnteredAt(_panel.Store.Events(Model.Id)) : null;
                _enteredIsStale = false;
            }

            return _enteredToday;
        }
    }

    public void Dispose()
    {
        Model.PropertyChanged -= OnChanged;
        _panel.Flow.PropertyChanged -= OnChanged;
        _panel.Store.Changed -= OnStoreChanged;
        _panel.Clock.MinuteTicked -= OnMinute;
    }

    private void OnStoreChanged(object? sender, EventArgs e)
    {
        _enteredIsStale = true;
        Subtasks.Update(_panel.Store.Subtasks(Model.Id));
        RaiseAll();
    }

    private void OnMinute(object? sender, EventArgs e) => RaiseAll();

    private void OnChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (sender is PriorityDetailModel && e.PropertyName is nameof(PriorityDetailModel.TitleDraft) or nameof(PriorityDetailModel.TitleState))
        {
            return;
        }

        if (sender is PriorityDetailModel && e.PropertyName == nameof(PriorityDetailModel.Priority))
        {
            _enteredIsStale = true;
        }

        RaiseAll();
    }

    private void RaiseAll() => Raise(
        nameof(BackLabel), nameof(BackName), nameof(StateLabel), nameof(Due), nameof(Since), nameof(SubtasksChip),
        nameof(Level), nameof(List), nameof(Repeat), nameof(DueAt), nameof(HasDue), nameof(AlertText),
        nameof(IsConfirming), nameof(Confirmation), nameof(OpenSubtasksHint), nameof(Created), nameof(SaveFailed));
}
