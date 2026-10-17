using DailyZGT.Core.Domain;

namespace DailyZGT.Core.Rules;

// F08. A done priority is in Hechas for 24 hours after it was marked done, then it moves to the history.
public static class DoneWindow
{
    public static readonly TimeSpan Length = TimeSpan.FromHours(24);

    public static DateTime Cutoff(DateTime now) => LocalTime.Truncated(now) - Length;

    public static bool IsRecent(DateTime doneAt, DateTime now) => doneAt > Cutoff(now);

    public static bool IsHistory(DateTime doneAt, DateTime now) => !IsRecent(doneAt, now);

    // F19. The footer count starts at local midnight for Hoy and at the ISO Monday for Semana.
    public static DateTime PeriodStart(PriorityList list, DateTime now) =>
        list == PriorityList.Today ? LocalTime.StartOfDay(now) : LocalTime.StartOfWeek(now);
}

public sealed record DoneDayGroup(string Day, DateTime Date, IReadOnlyList<Priority> Priorities);

public static class DoneHistory
{
    public static IReadOnlyList<DoneDayGroup> Groups(IEnumerable<Priority> priorities) =>
        priorities
            .Where(priority => priority.DoneAt is not null)
            .GroupBy(priority => LocalTime.DayKey(priority.DoneAt!.Value))
            .Select(day =>
            {
                var sorted = day
                    .OrderByDescending(priority => priority.DoneAt)
                    .ThenByDescending(priority => priority.Position)
                    .ThenBy(priority => priority.Id, StringComparer.Ordinal)
                    .ToList();
                return new DoneDayGroup(day.Key, sorted[0].DoneAt!.Value, sorted);
            })
            .OrderByDescending(group => group.Day, StringComparer.Ordinal)
            .ToList();
}
