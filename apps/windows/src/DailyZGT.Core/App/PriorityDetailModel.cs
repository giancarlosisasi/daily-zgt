using DailyZGT.Core.Domain;
using DailyZGT.Core.Store;

namespace DailyZGT.Core.App;

// F09. The title field: Idle shows the saved title, Editing keeps the person's draft.
public enum TitleEditState { Idle, Editing }

// F09, F10, F11. The open detail view of one open priority. The panel creates it, refreshes it after every
// change of the data, and disposes it when the view closes, which saves the note.
public sealed class PriorityDetailModel : ObservableModel, IDisposable
{
    private readonly AppStore _store;
    private readonly UiClock _clock;
    private readonly Action<PriorityList> _onMoved;
    private Priority _priority;
    private string _titleDraft;
    private TitleEditState _titleState = TitleEditState.Idle;
    private bool _moveWasBlocked;
    private bool _saveFailed;

    // onMoved selects the new list in the panel, so the back button names it.
    public PriorityDetailModel(AppStore store, UiClock clock, Priority priority, Action<PriorityList> onMoved)
    {
        _store = store;
        _clock = clock;
        _onMoved = onMoved;
        _priority = priority;
        _titleDraft = priority.Title;
        Note = new PriorityNoteModel(store, clock, priority.Id);
        Subtasks = new SubtaskEditor(store, priority.Id);
    }

    public string Id => _priority.Id;

    public Priority Priority
    {
        get => _priority;
        private set
        {
            if (Set(ref _priority, value))
            {
                Raise(nameof(ShowsLimitNotice));
            }
        }
    }

    public PriorityNoteModel Note { get; }

    public SubtaskEditor Subtasks { get; }

    public string TitleDraft
    {
        get => _titleDraft;
        set => Set(ref _titleDraft, value);
    }

    public TitleEditState TitleState
    {
        get => _titleState;
        private set => Set(ref _titleState, value);
    }

    // F06. "Hoy ya tiene 5 prioridades abiertas." under the Lista row, only after a blocked move, until Hoy
    // has room or the priority is no longer in Semana.
    public bool ShowsLimitNotice => _moveWasBlocked && Priority.List == PriorityList.Week && !_store.CanAddToToday;

    // "No se pudo guardar el cambio."
    public bool SaveFailed
    {
        get => _saveFailed;
        private set => Set(ref _saveFailed, value);
    }

    // The title field got the focus.
    public void BeginTitleEdit() => TitleState = TitleEditState.Editing;

    // Enter, or a click outside the field.
    public void CommitTitle()
    {
        if (TitleEdit.TitleToSave(TitleDraft, Priority.Title) is { } title)
        {
            Write(() => _store.EditTitle(Id, title));
        }
        TitleDraft = Priority.Title;
        TitleState = TitleEditState.Idle;
    }

    // Escape.
    public void DiscardTitle()
    {
        TitleDraft = Priority.Title;
        TitleState = TitleEditState.Idle;
    }

    public void SetLevel(PriorityLevel level) => Write(() => _store.SetLevel(Id, level));

    public void SetDue(DateTime? dueAt) => Write(() => _store.SetDue(Id, dueAt));

    // "Sin fecha" starts at the next whole hour.
    public void PickDefaultDue() => SetDue(NewPriorityForm.NextWholeHour(_clock.Now));

    public void SetRepeat(RepeatRule rule) => Write(() => _store.SetRepeat(Id, rule));

    // The Lista row. A move from Semana to Hoy can hit the limit of F06.
    public void SetList(PriorityList list)
    {
        MoveOutcome outcome;
        try
        {
            outcome = _store.MoveToList(Id, list);
        }
        catch (StoreException)
        {
            SaveFailed = true;
            return;
        }
        SaveFailed = false;
        switch (outcome)
        {
            case MoveOutcome.Moved moved:
                _moveWasBlocked = false;
                Priority = moved.Priority;
                _onMoved(list);
                break;
            case MoveOutcome.BlockedByTodayLimit:
                _moveWasBlocked = true;
                Raise(nameof(ShowsLimitNotice));
                break;
        }
    }

    // The panel calls this after every change of the data while the priority is still open.
    public void Refresh()
    {
        if (_store.Find(Id) is { } priority)
        {
            Priority = priority;
        }
        if (TitleState == TitleEditState.Idle)
        {
            TitleDraft = Priority.Title;
        }
        Raise(nameof(ShowsLimitNotice));
        Note.Sync();
    }

    // Closing the view saves the note at once.
    public void Dispose()
    {
        Note.Flush();
        Note.Dispose();
    }

    private void Write(Func<Priority> write)
    {
        try
        {
            Priority = write();
            SaveFailed = false;
        }
        catch (StoreException)
        {
            SaveFailed = true;
        }
    }
}
