using DailyZGT.Core.Domain;
using DailyZGT.Core.Localization;

namespace DailyZGT.Core.Alerts;

// What the adapter must do to make the system match the database, in this order:
// save Save, remove RemovePending, remove RemoveDelivered, then Add each request.
public sealed record AlertReconcilePlan(
    AlertAuthorization Authorization,
    DateTime? NextFireAt,
    IReadOnlyList<PriorityAlert> Save,
    IReadOnlyList<string> RemovePending,
    IReadOnlyList<string> RemoveDelivered,
    IReadOnlyList<AlertRequest> Add);

public static class AlertReconciler
{
    // `scheduledRows` are the rows with status Scheduled. `pending` is what the system holds now.
    // The test alert is never removed. With alerts off, nothing is added.
    public static AlertReconcilePlan Plan(
        IReadOnlyList<Priority> open,
        IEnumerable<PriorityAlert> scheduledRows,
        IEnumerable<AlertRequest> pending,
        AlertAuthorization authorization,
        DateTime now,
        Texts texts,
        Func<string>? makeId = null)
    {
        var authorized = authorization == AlertAuthorization.Authorized;
        var changes = AlertPlanner.Changes(open, scheduledRows, now, authorized, makeId);
        var pendingList = pending.ToList();

        var kept = changes.Scheduled.Select(row => row.Id).ToHashSet();
        var unwanted = pendingList
            .Select(request => request.Id)
            .Where(id => !kept.Contains(id) && id != AlertRequest.TestId)
            .Union(changes.Cancelled)
            .Order(StringComparer.Ordinal)
            .ToList();

        var add = new List<AlertRequest>();
        if (authorized)
        {
            var pendingById = new Dictionary<string, AlertRequest>();
            foreach (var request in pendingList)
            {
                pendingById.TryAdd(request.Id, request);
            }

            var priorities = open.ToDictionary(priority => priority.Id);
            foreach (var row in changes.Scheduled)
            {
                if (!priorities.TryGetValue(row.PriorityId, out var priority)
                    || AlertRequest.From(row, priority, texts) is not { } request
                    || (pendingById.TryGetValue(request.Id, out var held) && held == request))
                {
                    continue;
                }

                add.Add(request);
            }
        }

        DateTime? next = changes.Scheduled.Count > 0 ? changes.Scheduled.Min(row => row.FireAt) : null;
        return new AlertReconcilePlan(
            authorization,
            next,
            changes.Saved,
            unwanted,
            changes.Cancelled.Order(StringComparer.Ordinal).ToList(),
            add);
    }
}
