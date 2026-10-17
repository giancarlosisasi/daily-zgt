using DailyZGT.Core.Domain;

namespace DailyZGT.Core.Alerts;

// Windows has no permission prompt, so the macOS "not determined" state does not exist.
public enum AlertAuthorization { Authorized, Denied }

// One toast the system holds or must hold. PriorityId is null for the test alert.
public sealed record AlertRequest(string Id, string Title, string Body, DateTime FireAt, string? PriorityId)
{
    public const string TestId = "test-alert";

    public static AlertRequest Test(DateTime fireAt) =>
        new(TestId, AlertCopy.Overdue, AlertCopy.TestBody, fireAt, null);

    public static AlertRequest? From(PriorityAlert alert, Priority priority) =>
        priority.DueAt is { } due
            ? new AlertRequest(alert.Id, AlertCopy.Title(alert.FireAt, due), priority.Title, alert.FireAt, priority.Id)
            : null;
}
