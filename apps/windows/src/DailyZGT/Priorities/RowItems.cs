using System.Collections.ObjectModel;
using System.Windows;
using System.Windows.Input;
using DailyZGT.Core.App;
using DailyZGT.Core.Domain;
using DailyZGT.Core.Localization;
using DailyZGT.Core.Rules;

namespace DailyZGT.Priorities;

// What one open row draws (F04, F07, F10, F12, F13). The list keeps one item per priority across redraws,
// so a row keeps its controls, its hover and the focus of its subtask field.
public sealed class OpenRowItem : ObservableModel
{
    private readonly Texts _texts;
    private string _title = "";
    private PriorityLevel _level;
    private DueChip? _due;
    private DueChip? _since;
    private string? _ratio;
    private bool _hasNote;
    private RowPhase _phase;
    private bool _isExpanded;
    private bool _isHighlighted;
    private string? _openSubtasksHint;

    public OpenRowItem(string id, PanelState panel, bool isNew)
    {
        Id = id;
        IsNew = isNew;
        _texts = UiText.Current;
        Subtasks = new SubtaskListItem(new SubtaskEditor(panel.Store, id));
        ToggleSubtasks = new RelayCommand(() => panel.Flow.ToggleSubtasks(id));
        ToggleDone = new RelayCommand(() => panel.Flow.ToggleConfirmation(id));
        CancelDone = new RelayCommand(panel.Flow.CancelConfirmation);
        ConfirmDone = new RelayCommand(() => panel.Flow.ConfirmDone(id, DoneOrigin.List));
        Open = new RelayCommand(() => panel.OpenDetail(id));
        Delete = new RelayCommand(() => panel.Flow.Delete(id));
    }

    public string Id { get; }

    // Added after the list was first drawn, so it enters with rowIn.
    public bool IsNew { get; }

    public SubtaskListItem Subtasks { get; }

    public ICommand ToggleSubtasks { get; }

    public ICommand ToggleDone { get; }

    public ICommand CancelDone { get; }

    public ICommand ConfirmDone { get; }

    public ICommand Open { get; }

    public ICommand Delete { get; }

    public string RowId => "PriorityRow_" + Id;

    public string TitleId => "RowTitle_" + Id;

    public string CheckboxId => "RowCheckbox_" + Id;

    public string CaretId => "RowCaret_" + Id;

    public string DeleteId => "RowDelete_" + Id;

    public string Title
    {
        get => _title;
        private set
        {
            if (Set(ref _title, value))
            {
                Raise(nameof(CheckboxName));
            }
        }
    }

    public string CheckboxName => _texts.MarkDoneCheckbox(Title);

    public PriorityLevel Level
    {
        get => _level;
        private set => Set(ref _level, value);
    }

    public DueChip? Due
    {
        get => _due;
        private set => Set(ref _due, value);
    }

    // F13. Only in Hoy.
    public DueChip? Since
    {
        get => _since;
        private set => Set(ref _since, value);
    }

    public string? Ratio
    {
        get => _ratio;
        private set => Set(ref _ratio, value);
    }

    public bool HasNote
    {
        get => _hasNote;
        private set => Set(ref _hasNote, value);
    }

    public RowPhase Phase
    {
        get => _phase;
        private set
        {
            if (Set(ref _phase, value))
            {
                Raise(nameof(IsChecked), nameof(IsLeaving), nameof(Confirmation));
            }
        }
    }

    // F07. The checkbox shows checked while the bar asks, and while the row leaves.
    public bool IsChecked => Phase != RowPhase.Idle;

    // The confirm bar stays while the row leaves. Null draws no bar, so only one bar is in the tree.
    public OpenRowItem? Confirmation => Phase != RowPhase.Idle ? this : null;

    public bool IsLeaving => Phase == RowPhase.Leaving;

    public bool IsExpanded
    {
        get => _isExpanded;
        private set
        {
            if (Set(ref _isExpanded, value))
            {
                Raise(nameof(CaretState), nameof(ExpandedSubtasks));
            }
        }
    }

    public SubtaskListItem? ExpandedSubtasks => IsExpanded ? Subtasks : null;

    public string CaretState => IsExpanded ? _texts.StateExpanded : _texts.StateCollapsed;

    public bool IsHighlighted
    {
        get => _isHighlighted;
        private set => Set(ref _isHighlighted, value);
    }

    // "Queda 1 subtarea abierta." in the confirm bar.
    public string? OpenSubtasksHint
    {
        get => _openSubtasksHint;
        private set => Set(ref _openSubtasksHint, value);
    }

    public void Update(Priority priority, IReadOnlyList<Subtask> subtasks, DateTime? enteredToday, DateTime now, PriorityFlow flow)
    {
        var progress = SubtaskProgress.Of(subtasks);
        Title = priority.Title;
        Level = priority.Level;
        Due = DueChip.Make(priority.DueAt, now, _texts);
        Since = TodayEntryChip.Make(enteredToday, now, _texts);
        Ratio = progress.RatioLabel(_texts);
        HasNote = PriorityNote.IsPresent(priority.Note);
        Phase = flow.PhaseOf(Id);
        IsExpanded = flow.IsExpanded(Id);
        IsHighlighted = flow.HighlightedId == Id;
        OpenSubtasksHint = progress.OpenSubtasksLabel(_texts);
        Subtasks.Update(subtasks);
    }
}

// F10. The subtasks of one priority and the field that adds one, under a row or in the detail view.
public sealed class SubtaskListItem : ObservableModel
{
    public SubtaskListItem(SubtaskEditor editor)
    {
        Editor = editor;
        Add = new RelayCommand(editor.Add);
    }

    public SubtaskEditor Editor { get; }

    public ICommand Add { get; }

    public ObservableCollection<SubtaskItem> Items { get; } = [];

    public void Update(IReadOnlyList<Subtask> subtasks) =>
        Keyed.Sync(Items, subtasks, s => s.Id, item => item.Id, s => new SubtaskItem(s.Id, Editor), (item, s) => item.Update(s));
}

public sealed class SubtaskItem : ObservableModel
{
    private string _title = "";
    private bool _isDone;

    public SubtaskItem(string id, SubtaskEditor editor)
    {
        Id = id;
        Toggle = new RelayCommand(() => editor.Toggle(id));
    }

    public string Id { get; }

    public string AutomationId => "Subtask_" + Id;

    public ICommand Toggle { get; }

    public string Title
    {
        get => _title;
        private set => Set(ref _title, value);
    }

    public bool IsDone
    {
        get => _isDone;
        private set => Set(ref _isDone, value);
    }

    public void Update(Subtask subtask)
    {
        Title = subtask.Title;
        IsDone = subtask.IsDone;
    }
}

// F08. A row of Hechas or of the history: a check, the struck title, Regresar and the trash.
public sealed class DoneRowItem(Priority priority, PriorityFlow flow, bool inHistory = false)
{
    public string Id => priority.Id;

    // Hechas lines the check up with the row checkboxes. The history has no checkboxes to line up with.
    public Thickness Indent { get; } = new(inHistory ? 8 : 30, 0, 4, 0);

    public string Title => priority.Title;

    public string RowId => "DoneRow_" + priority.Id;

    public string ReopenId => "ReopenButton_" + priority.Id;

    public string DeleteId => "RowDelete_" + priority.Id;

    public ICommand Reopen { get; } = new RelayCommand(() => flow.Restore(priority.Id));

    public ICommand Delete { get; } = new RelayCommand(() => flow.Delete(priority.Id));
}

// F08. One day of the history.
public sealed record HistoryGroupItem(string Title, IReadOnlyList<DoneRowItem> Rows);

public static class Keyed
{
    // Makes `items` follow `sources` in order. An item whose key stays keeps its object, so WPF keeps its row.
    public static void Sync<TItem, TSource>(
        ObservableCollection<TItem> items,
        IReadOnlyList<TSource> sources,
        Func<TSource, string> key,
        Func<TItem, string> itemKey,
        Func<TSource, TItem> create,
        Action<TItem, TSource> update)
        where TItem : class
    {
        var keys = sources.Select(key).ToHashSet();
        var existing = new Dictionary<string, TItem>();
        for (var index = items.Count - 1; index >= 0; index--)
        {
            var current = itemKey(items[index]);
            if (keys.Contains(current))
            {
                existing[current] = items[index];
            }
            else
            {
                items.RemoveAt(index);
            }
        }

        for (var index = 0; index < sources.Count; index++)
        {
            var source = sources[index];
            if (!existing.TryGetValue(key(source), out var item))
            {
                item = create(source);
                items.Insert(index, item);
            }
            else
            {
                var at = items.IndexOf(item);
                if (at != index)
                {
                    items.Move(at, index);
                }
            }

            update(item, source);
        }
    }
}
