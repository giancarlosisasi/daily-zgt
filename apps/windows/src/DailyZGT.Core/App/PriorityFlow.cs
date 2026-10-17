using System.Collections.Immutable;
using DailyZGT.Core.Domain;
using DailyZGT.Core.Store;

namespace DailyZGT.Core.App;

// F07. What the row shows: the checkbox and the confirmation bar for Confirming and Leaving, and a leaving
// row slides out and ignores clicks.
public enum RowPhase { Idle, Confirming, Leaving }

// F07. A done from the list slides the row out first. A done from the detail view writes at once.
public enum DoneOrigin { List, Detail }

public enum AddResult { Added, EmptyTitle, BlockedByTodayLimit, SaveFailed }

// F07. The bar of the last priority marked done. A new Token means a new bar, so the view replays its entry.
public sealed record PendingUndo(string PriorityId, string Title, int Token, DateTimeOffset StartedAt, TimeSpan Lifetime)
{
    public double RemainingFraction(DateTimeOffset now) =>
        Lifetime <= TimeSpan.Zero ? 0 : Math.Clamp(1 - (now - StartedAt) / Lifetime, 0, 1);

    // F22. With reduced motion the progress line stays full.
    public double LineFraction(DateTimeOffset now, bool reduceMotion) => reduceMotion ? 1 : RemainingFraction(now);
}

// F05, F07, F08, F15. The yellow flash of a row, and whether the list still has to scroll to it.
public sealed record Highlight(string PriorityId, bool NeedsScroll);

// The list actions of F05, F07, F08 and F10: one confirmation at a time, the leave, the undo bar, the flash,
// the open subtask rows, and one save-failed flag for all of them.
public sealed class PriorityFlow : ObservableModel, IDisposable
{
    public static readonly TimeSpan UndoLifetime = TimeSpan.FromSeconds(5);
    public static readonly TimeSpan HighlightLifetime = TimeSpan.FromMilliseconds(1400);

    private readonly AppStore _store;
    private readonly UiClock _clock;
    private readonly MotionPolicy _motion;
    private readonly Dictionary<string, IDisposable> _leaving = [];
    private ImmutableHashSet<string> _expandedIds = [];
    private string? _confirmingId;
    private PendingUndo? _undo;
    private Highlight? _highlight;
    private bool _saveFailed;
    private IDisposable? _undoTimer;
    private IDisposable? _highlightTimer;
    private int _lastToken;

    public PriorityFlow(AppStore store, UiClock clock, MotionPolicy motion)
    {
        _store = store;
        _clock = clock;
        _motion = motion;
    }

    public string? ConfirmingId
    {
        get => _confirmingId;
        private set => Set(ref _confirmingId, value);
    }

    public IReadOnlyCollection<string> LeavingIds => _leaving.Keys.ToList();

    public PendingUndo? Undo
    {
        get => _undo;
        private set => Set(ref _undo, value);
    }

    public Highlight? Highlight
    {
        get => _highlight;
        private set
        {
            if (Set(ref _highlight, value))
            {
                Raise(nameof(HighlightedId), nameof(ScrollTargetId));
            }
        }
    }

    public string? HighlightedId => Highlight?.PriorityId;

    public string? ScrollTargetId => Highlight is { NeedsScroll: true } highlight ? highlight.PriorityId : null;

    // F04, F10. "No se pudo guardar el cambio." under the list.
    public bool SaveFailed
    {
        get => _saveFailed;
        private set => Set(ref _saveFailed, value);
    }

    // F04. The rows whose subtasks are open. Kept while a detail view is open, not kept across launches.
    public IReadOnlySet<string> ExpandedIds => _expandedIds;

    public RowPhase PhaseOf(string id) =>
        IsLeaving(id) ? RowPhase.Leaving : ConfirmingId == id ? RowPhase.Confirming : RowPhase.Idle;

    public bool IsLeaving(string id) => _leaving.ContainsKey(id);

    public bool IsExpanded(string id) => _expandedIds.Contains(id);

    public void ToggleSubtasks(string id)
    {
        _expandedIds = _expandedIds.Contains(id) ? _expandedIds.Remove(id) : _expandedIds.Add(id);
        Raise(nameof(ExpandedIds));
    }

    // The checkbox, or "Marcar como hecha". A second click cancels. Another row's click moves the confirmation.
    public void ToggleConfirmation(string id)
    {
        if (IsLeaving(id))
        {
            return;
        }
        ConfirmingId = ConfirmingId == id ? null : id;
    }

    public void CancelConfirmation()
    {
        if (ConfirmingId is { } id && IsLeaving(id))
        {
            return;
        }
        ConfirmingId = null;
    }

    // "Hecha".
    public void ConfirmDone(string id, DoneOrigin origin)
    {
        if (IsLeaving(id))
        {
            return;
        }
        var delay = origin == DoneOrigin.List ? _motion.LeaveDelay : TimeSpan.Zero;
        if (delay <= TimeSpan.Zero)
        {
            CompleteDone(id);
            return;
        }
        _leaving[id] = _clock.After(delay, () => FinishLeaving(id));
        Raise(nameof(LeavingIds));
    }

    // "Deshacer".
    public void UndoDone()
    {
        if (Undo is not { } pending)
        {
            return;
        }
        if (Write(() => _store.Restore(pending.PriorityId)))
        {
            ClearUndo();
            Flash(pending.PriorityId);
        }
    }

    // F08. "Regresar".
    public void Restore(string id)
    {
        if (!Write(() => _store.Restore(id)))
        {
            return;
        }
        if (Undo?.PriorityId == id)
        {
            ClearUndo();
        }
        Flash(id);
    }

    // The trash button of a row, a done row, a history row or the detail view.
    public void Delete(string id)
    {
        if (!Write(() => _store.Delete(id)))
        {
            return;
        }
        if (_leaving.Remove(id, out var timer))
        {
            timer.Dispose();
            Raise(nameof(LeavingIds));
        }
        if (ConfirmingId == id)
        {
            ConfirmingId = null;
        }
        if (Undo?.PriorityId == id)
        {
            ClearUndo();
        }
    }

    // F05. The form adds through the flow, so a new row flashes and the list scrolls to it.
    public AddResult Add(string title, PriorityList list, PriorityLevel level, DateTime? dueAt)
    {
        AddOutcome outcome;
        try
        {
            outcome = _store.AddPriority(title, list, level, dueAt);
        }
        catch (StoreException)
        {
            SaveFailed = true;
            return AddResult.SaveFailed;
        }
        switch (outcome)
        {
            case AddOutcome.Added added:
                SaveFailed = false;
                Flash(added.Priority.Id);
                return AddResult.Added;
            case AddOutcome.BlockedByTodayLimit:
                return AddResult.BlockedByTodayLimit;
            default:
                return AddResult.EmptyTitle;
        }
    }

    // The row turns yellow for 1.4 s and the list scrolls to it. A new flash replaces the old one.
    public void Flash(string id)
    {
        _highlightTimer?.Dispose();
        Highlight = new Highlight(id, NeedsScroll: true);
        _highlightTimer = _clock.After(HighlightLifetime, () =>
        {
            _highlightTimer = null;
            Highlight = null;
        });
    }

    public void ScrollWasHandled(string id)
    {
        if (Highlight is { NeedsScroll: true } highlight && highlight.PriorityId == id)
        {
            Highlight = highlight with { NeedsScroll = false };
        }
    }

    public void Dispose()
    {
        foreach (var timer in _leaving.Values)
        {
            timer.Dispose();
        }
        _leaving.Clear();
        _undoTimer?.Dispose();
        _highlightTimer?.Dispose();
    }

    private void FinishLeaving(string id)
    {
        if (!_leaving.Remove(id))
        {
            return;
        }
        Raise(nameof(LeavingIds));
        if (_store.Find(id) is null)
        {
            return;
        }
        CompleteDone(id);
    }

    private void CompleteDone(string id)
    {
        Priority done;
        try
        {
            done = _store.MarkDone(id);
        }
        catch (StoreException)
        {
            SaveFailed = true;
            return;
        }
        SaveFailed = false;
        if (ConfirmingId == id)
        {
            ConfirmingId = null;
        }
        StartUndo(done);
    }

    private void StartUndo(Priority done)
    {
        _undoTimer?.Dispose();
        Undo = new PendingUndo(done.Id, done.Title, ++_lastToken, _clock.Instant, UndoLifetime);
        _undoTimer = _clock.After(UndoLifetime, ClearUndo);
    }

    private void ClearUndo()
    {
        _undoTimer?.Dispose();
        _undoTimer = null;
        Undo = null;
    }

    private bool Write(Func<Priority> write)
    {
        try
        {
            write();
        }
        catch (StoreException)
        {
            SaveFailed = true;
            return false;
        }
        SaveFailed = false;
        return true;
    }
}
