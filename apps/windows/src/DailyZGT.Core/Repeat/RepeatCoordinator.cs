using DailyZGT.Core.Domain;
using DailyZGT.Core.Store;

namespace DailyZGT.Core.Repeat;

// F14. Adds the daily copies at start and after every change of the data. The app also calls Run when the
// day changes and when it comes to the front (F21).
public sealed class RepeatCoordinator(AppStore store) : IDisposable
{
    private bool _running;

    public void Start()
    {
        store.Changed += OnChanged;
        Run();
    }

    public IReadOnlyList<Priority> Run() => store.AddRepeatCopies();

    public void Dispose() => store.Changed -= OnChanged;

    private void OnChanged(object? sender, EventArgs e)
    {
        // The copies raise Changed themselves. The nested run would find nothing to add.
        if (_running)
        {
            return;
        }
        _running = true;
        try
        {
            Run();
        }
        catch (StoreException)
        {
            // The macOS app only logs this. The next change, day change or activation tries again.
        }
        finally
        {
            _running = false;
        }
    }
}
