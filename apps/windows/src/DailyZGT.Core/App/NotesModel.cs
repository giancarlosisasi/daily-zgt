using DailyZGT.Core.Domain;
using DailyZGT.Core.Store;

namespace DailyZGT.Core.App;

// F16. The note of the current day or ISO week. It saves 400 ms after the last keystroke and at once on
// Flush, which the panel calls on a tab or scope change, when the settings open, on focus loss and on quit.
// Sync finds a new day or week (at the midnight tick of the clock, on focus, after a change of the data,
// and every 30 s) and takes a change from outside only while the person has no unsaved edit.
public sealed class NotesModel : ObservableModel, IDisposable
{
    public static readonly TimeSpan SaveDelay = TimeSpan.FromMilliseconds(400);
    public static readonly TimeSpan CheckInterval = TimeSpan.FromSeconds(30);

    private readonly AppStore _store;
    private readonly UiClock _clock;
    private readonly IDisposable _check;
    private NoteScope _scope;
    private string _period;
    private string _text;
    private bool _hasUnsavedEdit;
    private bool _saveFailed;
    private IDisposable? _saveTimer;

    public NotesModel(AppStore store, UiClock clock, NoteScope scope)
    {
        _store = store;
        _clock = clock;
        _scope = scope;
        _period = store.Period(scope);
        _text = store.NoteBody(scope, _period);
        _check = clock.Every(CheckInterval, Sync);
        clock.DayChanged += OnDayChanged;
    }

    // "Notas de hoy" or "Notas de la semana".
    public NoteScope Scope
    {
        get => _scope;
        private set => Set(ref _scope, value);
    }

    // The day key (yyyy-MM-dd) or the week key (yyyy-Www) the text belongs to.
    public string Period
    {
        get => _period;
        private set => Set(ref _period, value);
    }

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

    // "No se pudo guardar la nota." in place of "Se guarda al escribir."
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
        if (Text == _store.NoteBody(Scope, Period))
        {
            HasUnsavedEdit = false;
            return;
        }
        try
        {
            _store.SaveNote(Scope, Text, Period);
        }
        catch (StoreException)
        {
            SaveFailed = true;
            return;
        }
        HasUnsavedEdit = false;
        SaveFailed = false;
    }

    public void SelectScope(NoteScope scope)
    {
        if (scope == Scope)
        {
            return;
        }
        Flush();
        Scope = scope;
        Reload();
    }

    public void Sync()
    {
        if (_store.Period(Scope) != Period)
        {
            Flush();
            Reload();
            return;
        }
        if (HasUnsavedEdit)
        {
            return;
        }
        Set(ref _text, _store.NoteBody(Scope, Period), nameof(Text));
    }

    public void Dispose()
    {
        CancelTimer();
        _check.Dispose();
        _clock.DayChanged -= OnDayChanged;
    }

    private void OnDayChanged(object? sender, EventArgs e) => Sync();

    private void Reload()
    {
        CancelTimer();
        Period = _store.Period(Scope);
        Set(ref _text, _store.NoteBody(Scope, Period), nameof(Text));
        HasUnsavedEdit = false;
    }

    private void CancelTimer()
    {
        _saveTimer?.Dispose();
        _saveTimer = null;
    }
}
