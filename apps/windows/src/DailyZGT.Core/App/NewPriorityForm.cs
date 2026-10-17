using DailyZGT.Core.Domain;
using DailyZGT.Core.Store;

namespace DailyZGT.Core.App;

// F05 and F06. The "Nueva prioridad" form. Escape closes it and keeps the text, Cancelar closes it and clears
// it, and the limit of Hoy keeps it open with its text.
public sealed class NewPriorityForm : ObservableModel
{
    private readonly AppStore _store;
    private readonly PriorityFlow _flow;
    private readonly UiClock _clock;
    private bool _isOpen;
    private string _title = "";
    private PriorityLevel _level = PriorityLevel.Medium;
    private DateTime? _dueAt;
    private PriorityList _list;
    private bool _isBlockedByLimit;

    public NewPriorityForm(AppStore store, PriorityFlow flow, UiClock clock, PriorityList list)
    {
        _store = store;
        _flow = flow;
        _clock = clock;
        _list = list;
    }

    public bool IsOpen
    {
        get => _isOpen;
        private set => Set(ref _isOpen, value);
    }

    public string Title
    {
        get => _title;
        set => Set(ref _title, value);
    }

    public PriorityLevel Level
    {
        get => _level;
        set => Set(ref _level, value);
    }

    public DateTime? DueAt
    {
        get => _dueAt;
        set
        {
            if (Set(ref _dueAt, value))
            {
                Raise(nameof(ShowsDueNote));
            }
        }
    }

    // The list the form adds to: the open scope of the panel.
    public PriorityList List
    {
        get => _list;
        set
        {
            if (Set(ref _list, value))
            {
                Raise(nameof(ShowsLimitNotice));
            }
        }
    }

    // "Alerta con sonido 30 min antes y al vencer", or the alerts-off line of F15.
    public bool ShowsDueNote => DueAt is not null;

    public bool IsBlockedByLimit
    {
        get => _isBlockedByLimit;
        private set
        {
            if (Set(ref _isBlockedByLimit, value))
            {
                Raise(nameof(ShowsLimitNotice));
            }
        }
    }

    // F06. Shown after a blocked add, in Hoy only, until Hoy has room again.
    public bool ShowsLimitNotice => List == PriorityList.Today && IsBlockedByLimit && !_store.CanAddToToday;

    // F05. "Sin fecha" starts the picker at the next whole hour.
    public static DateTime NextWholeHour(DateTime now) =>
        new DateTime(now.Year, now.Month, now.Day, now.Hour, 0, 0, DateTimeKind.Local).AddHours(1);

    public void Open() => IsOpen = true;

    // Escape.
    public void Close() => IsOpen = false;

    // "Cancelar".
    public void Cancel()
    {
        IsOpen = false;
        IsBlockedByLimit = false;
        Title = "";
        Level = PriorityLevel.Medium;
        DueAt = null;
    }

    // Enter or "Añadir". A blank title adds nothing and shows nothing.
    public void Submit()
    {
        switch (_flow.Add(Title, List, Level, DueAt))
        {
            case AddResult.Added:
                Cancel();
                break;
            case AddResult.BlockedByTodayLimit:
                IsBlockedByLimit = true;
                break;
            case AddResult.SaveFailed:
                IsBlockedByLimit = false;
                break;
        }
    }

    public void PickDefaultDue() => DueAt = NextWholeHour(_clock.Now);

    // The x button.
    public void ClearDue() => DueAt = null;

    // The panel calls this after every change of the data.
    public void Refresh() => Raise(nameof(ShowsLimitNotice));
}
