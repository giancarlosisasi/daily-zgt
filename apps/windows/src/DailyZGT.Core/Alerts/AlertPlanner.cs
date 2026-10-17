using DailyZGT.Core.Domain;

namespace DailyZGT.Core.Alerts;

public sealed record WantedAlert(string PriorityId, AlertKind Kind, DateTime FireAt);

public sealed record AlertChanges(
    IReadOnlyList<PriorityAlert> Saved,
    IReadOnlyList<PriorityAlert> Scheduled,
    IReadOnlyList<string> Cancelled);

public static class AlertPlanner
{
    public static readonly TimeSpan LeadTime = TimeSpan.FromMinutes(30);
    public static readonly TimeSpan SnoozeTime = TimeSpan.FromMinutes(15);

    public static IReadOnlyList<WantedAlert> Wanted(IEnumerable<Priority> priorities, DateTime now) =>
        priorities
            .Where(priority => !priority.IsDone && priority.DueAt is not null)
            .SelectMany(priority => new[]
            {
                new WantedAlert(priority.Id, AlertKind.Before30m, priority.DueAt!.Value - LeadTime),
                new WantedAlert(priority.Id, AlertKind.AtDue, priority.DueAt.Value),
            })
            .Where(alert => alert.FireAt > now)
            .ToList();

    // Compares the scheduled rows with the alerts the open priorities want. Applying Saved to the rows
    // and running again gives no change.
    public static AlertChanges Changes(
        IReadOnlyList<Priority> open,
        IEnumerable<PriorityAlert> rows,
        DateTime now,
        bool deliversAlerts = true,
        Func<string>? makeId = null)
    {
        makeId ??= () => Guid.NewGuid().ToString();
        var saved = new List<PriorityAlert>();
        var scheduled = new List<PriorityAlert>();
        var cancelled = new List<string>();
        var unmet = Wanted(open, now).ToList();
        var withDue = open
            .Where(priority => !priority.IsDone && priority.DueAt is not null)
            .Select(priority => priority.Id)
            .ToHashSet();

        foreach (var row in rows.Where(row => row.Status == AlertStatus.Scheduled))
        {
            var next = row;
            if (row.FireAt <= now)
            {
                next = row with { Status = deliversAlerts ? AlertStatus.Delivered : AlertStatus.Cancelled };
            }
            else if (row.Kind == AlertKind.Snooze)
            {
                if (!withDue.Contains(row.PriorityId))
                {
                    next = row with { Status = AlertStatus.Cancelled };
                }
            }
            else
            {
                var index = unmet.FindIndex(alert => alert.PriorityId == row.PriorityId && alert.Kind == row.Kind);
                if (index >= 0)
                {
                    next = row with { FireAt = unmet[index].FireAt };
                    unmet.RemoveAt(index);
                }
                else
                {
                    next = row with { Status = AlertStatus.Cancelled };
                }
            }

            if (next != row)
            {
                saved.Add(next);
            }

            if (next.Status == AlertStatus.Scheduled)
            {
                scheduled.Add(next);
            }
            else if (next.Status == AlertStatus.Cancelled)
            {
                cancelled.Add(next.Id);
            }
        }

        foreach (var alert in unmet)
        {
            var row = new PriorityAlert(makeId(), alert.PriorityId, alert.Kind, alert.FireAt, AlertStatus.Scheduled);
            saved.Add(row);
            scheduled.Add(row);
        }

        return new AlertChanges(saved, scheduled, cancelled);
    }
}
