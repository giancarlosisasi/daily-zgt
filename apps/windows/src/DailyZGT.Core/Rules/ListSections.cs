using DailyZGT.Core.Domain;
using DailyZGT.Core.Localization;

namespace DailyZGT.Core.Rules;

// F03. What fills a list that has no open priority: `Todo listo en esta lista` after a recent done one,
// `Nada pendiente en esta lista.` otherwise.
public enum EmptyList { None, AllDone, NothingPending }

// F03, F08. The parts of a list around its open rows: the empty state, the Hechas section with the done
// priorities of the last 24 hours (most recent first) and the count of the Historial row. The section
// shows while the list has any done priority, so it reads `Hechas (0)` when all of them are older.
public sealed record ListSections(EmptyList Empty, bool ShowsDone, IReadOnlyList<Priority> RecentDone, int HistoryCount)
{
    public static ListSections Of(PriorityList list, StoreSnapshot snapshot, DateTime now)
    {
        var done = snapshot.Done.Where(priority => priority.List == list && priority.DoneAt is not null).ToList();
        var recent = done
            .Where(priority => DoneWindow.IsRecent(priority.DoneAt!.Value, now))
            .OrderByDescending(priority => priority.DoneAt)
            .ThenByDescending(priority => priority.Position)
            .ThenBy(priority => priority.Id, StringComparer.Ordinal)
            .ToList();
        var empty = snapshot.Open.Any(priority => priority.List == list) ? EmptyList.None
            : recent.Count > 0 ? EmptyList.AllDone
            : EmptyList.NothingPending;
        return new ListSections(empty, done.Count > 0, recent, done.Count - recent.Count);
    }

    // `Hechas (N)`.
    public string DoneHeader(Texts texts) => texts.DoneHeader(RecentDone.Count);
}
