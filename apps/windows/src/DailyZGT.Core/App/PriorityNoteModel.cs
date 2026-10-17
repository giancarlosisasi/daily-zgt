using DailyZGT.Core.Store;

namespace DailyZGT.Core.App;

// F04, F11. A note of only whitespace is stored empty and shows no note icon.
public static class PriorityNote
{
    public static string Stored(string text) => string.IsNullOrWhiteSpace(text) ? "" : text;

    public static bool IsPresent(string note) => Stored(note).Length > 0;
}

// F11. The NOTAS box of the detail view. It saves 400 ms after the last keystroke, and at once when the
// detail view closes or the panel loses the focus (Flush). A change from outside shows only while the person
// has no unsaved edit (Sync).
public sealed class PriorityNoteModel : ObservableModel, IDisposable
{
    public static readonly TimeSpan SaveDelay = TimeSpan.FromMilliseconds(400);

    private readonly AppStore _store;
    private readonly UiClock _clock;
    private string _text;
    private bool _hasUnsavedEdit;
    private bool _saveFailed;
    private IDisposable? _saveTimer;

    public PriorityNoteModel(AppStore store, UiClock clock, string priorityId)
    {
        _store = store;
        _clock = clock;
        PriorityId = priorityId;
        _text = store.Find(priorityId)?.Note ?? "";
    }

    public string PriorityId { get; }

    public string Text
    {
        get => _text;
        set => Edit(value);
    }

    public bool HasUnsavedEdit
    {
        get => _hasUnsavedEdit;
        private set => Set(ref _hasUnsavedEdit, value);
    }

    // "No se pudo guardar la nota."
    public bool SaveFailed
    {
        get => _saveFailed;
        private set => Set(ref _saveFailed, value);
    }

    public void Edit(string text)
    {
        if (!Set(ref _text, text, nameof(Text)))
        {
            return;
        }
        HasUnsavedEdit = true;
        _saveTimer?.Dispose();
        _saveTimer = _clock.After(SaveDelay, Flush);
    }

    public void Flush()
    {
        CancelTimer();
        if (!HasUnsavedEdit)
        {
            return;
        }
        if (_store.Find(PriorityId) is not { } current)
        {
            HasUnsavedEdit = false;
            return;
        }
        var note = PriorityNote.Stored(Text);
        if (note == current.Note)
        {
            HasUnsavedEdit = false;
            return;
        }
        try
        {
            _store.SetNote(PriorityId, note);
        }
        catch (StoreException)
        {
            SaveFailed = true;
            return;
        }
        HasUnsavedEdit = false;
        SaveFailed = false;
    }

    public void Sync()
    {
        if (HasUnsavedEdit)
        {
            return;
        }
        var stored = _store.Find(PriorityId)?.Note ?? "";
        if (stored != PriorityNote.Stored(Text))
        {
            Set(ref _text, stored, nameof(Text));
        }
    }

    public void Dispose() => CancelTimer();

    private void CancelTimer()
    {
        _saveTimer?.Dispose();
        _saveTimer = null;
    }
}
