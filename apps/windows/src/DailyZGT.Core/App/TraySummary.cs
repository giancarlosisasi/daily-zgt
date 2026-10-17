using DailyZGT.Core.Domain;
using DailyZGT.Core.Rules;
using DailyZGT.Core.Store;

namespace DailyZGT.Core.App;

// F01. What the tray icon shows: the open count of Hoy for the badge, and the next priority of Hoy for the
// tooltip when the "menu_bar_title" setting is on. Both follow every change of the data.
public sealed class TraySummary : ObservableModel, IDisposable
{
    private readonly AppStore? _store;
    private int? _count;
    private string? _title;

    public TraySummary(AppStore store)
    {
        _store = store;
        store.Changed += OnChanged;
        Update();
    }

    private TraySummary()
    {
    }

    // The app could not open its data: no badge, no title.
    public static TraySummary DataError() => new();

    public int? Count
    {
        get => _count;
        private set => Set(ref _count, value);
    }

    // Cut to 24 characters, or null when the setting is off or Hoy has no open priority.
    public string? Title
    {
        get => _title;
        private set => Set(ref _title, value);
    }

    public void Dispose()
    {
        if (_store is not null)
        {
            _store.Changed -= OnChanged;
        }
    }

    private void OnChanged(object? sender, EventArgs e) => Update();

    private void Update()
    {
        if (_store is null)
        {
            return;
        }
        Count = _store.OpenCount(PriorityList.Today);
        var next = _store.Snapshot.Open.FirstOrDefault(p => p.List == PriorityList.Today);
        Title = _store.Value(AppStateKeys.TrayTitle) ? TrayTitle.Text(next?.Title) : null;
    }
}
