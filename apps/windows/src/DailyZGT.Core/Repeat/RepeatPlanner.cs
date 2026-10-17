using DailyZGT.Core.Domain;

namespace DailyZGT.Core.Repeat;

public sealed record RepeatCopy(
    string SourceId,
    string SeriesId,
    string Title,
    string Note,
    PriorityLevel Level,
    DateTime? DueAt,
    IReadOnlyList<string> SubtaskTitles);

// F14. A series gets one open copy in Hoy when it has no open priority, the priority it finished last
// repeats daily, and that priority was done on a day before today.
public static class RepeatPlanner
{
    public static IReadOnlyList<RepeatCopy> Copies(
        IEnumerable<Priority> priorities,
        IReadOnlyDictionary<string, IReadOnlyList<Subtask>> subtasks,
        DateTime now,
        TimeZoneInfo zone)
    {
        var today = LocalTime.DayKey(now);
        return priorities
            .GroupBy(p => p.SeriesId)
            .Select(series => series.All(p => p.IsDone) ? series.MaxBy(DoneOrder, DoneOrderComparer.Instance) : null)
            .OfType<Priority>()
            .Where(last => last.RepeatRule == RepeatRule.Daily
                && string.CompareOrdinal(LocalTime.DayKey(last.DoneAt!.Value), today) < 0)
            .OrderBy(source => source.Position)
            .ThenBy(source => source.Id, StringComparer.Ordinal)
            .Select(source => new RepeatCopy(
                source.Id,
                source.SeriesId,
                source.Title,
                source.Note,
                source.Level,
                source.DueAt is { } due ? SameTime(due, now, zone) : null,
                (subtasks.TryGetValue(source.Id, out var list) ? list : [])
                    .OrderBy(s => s.Position)
                    .ThenBy(s => s.Id, StringComparer.Ordinal)
                    .Select(s => s.Title)
                    .ToList()))
            .ToList();
    }

    // The wall-clock time of `due` on the day of `now`. A time that the zone skips on that day
    // (the spring DST gap) moves to the first time after the gap, as Foundation's Calendar does.
    public static DateTime SameTime(DateTime due, DateTime now, TimeZoneInfo zone)
    {
        var time = new DateTime(now.Year, now.Month, now.Day, due.Hour, due.Minute, due.Second, DateTimeKind.Unspecified);
        if (zone.IsInvalidTime(time))
        {
            time = time.AddSeconds(-time.Second);
            while (zone.IsInvalidTime(time))
            {
                time = time.AddMinutes(1);
            }
        }
        return DateTime.SpecifyKind(time, DateTimeKind.Local);
    }

    private static (DateTime DoneAt, DateTime CreatedAt, int Position, string Id) DoneOrder(Priority p) =>
        (p.DoneAt ?? DateTime.MinValue, p.CreatedAt, p.Position, p.Id);

    private sealed class DoneOrderComparer : IComparer<(DateTime DoneAt, DateTime CreatedAt, int Position, string Id)>
    {
        public static readonly DoneOrderComparer Instance = new();

        public int Compare(
            (DateTime DoneAt, DateTime CreatedAt, int Position, string Id) x,
            (DateTime DoneAt, DateTime CreatedAt, int Position, string Id) y)
        {
            var order = x.DoneAt.CompareTo(y.DoneAt);
            if (order == 0) order = x.CreatedAt.CompareTo(y.CreatedAt);
            if (order == 0) order = x.Position.CompareTo(y.Position);
            return order != 0 ? order : string.CompareOrdinal(x.Id, y.Id);
        }
    }
}
