using DailyZGT.Core.Alerts;
using DailyZGT.Core.Domain;
using static DailyZGT.Core.Tests.Rules.RuleFixtures;

namespace DailyZGT.Core.Tests.Alerts;

internal static class AlertFixtures
{
    public static Priority AlertPriority(string id = "p1", string? due = null, bool done = false, string? title = null) =>
        MakePriority(id, due: due, done: done ? "2026-10-12T09:00:00" : null, title: title);

    public static PriorityAlert Row(
        string id,
        AlertKind kind,
        string at,
        string priority = "p1",
        AlertStatus status = AlertStatus.Scheduled) =>
        new(id, priority, kind, At(at), status);

    public static WantedAlert Wanted(AlertKind kind, string at, string priority = "p1") =>
        new(priority, kind, At(at));
}

public class AlertPlannerTests
{
    private static readonly DateTime Now = At("2026-10-12T10:00:00");

    private static IReadOnlyList<WantedAlert> WantedFor(params Priority[] priorities) =>
        AlertPlanner.Wanted(priorities, Now);

    [Fact]
    public void ADueInTwoHoursWantsTheAlertBeforeAndTheAlertAtTheDue() =>
        Assert.Equal(
            [
                AlertFixtures.Wanted(AlertKind.Before30m, "2026-10-12T11:30:00"),
                AlertFixtures.Wanted(AlertKind.AtDue, "2026-10-12T12:00:00"),
            ],
            WantedFor(AlertFixtures.AlertPriority(due: "2026-10-12T12:00:00")));

    [Fact]
    public void ADueIn29MinWantsOnlyTheAlertAtTheDue() =>
        Assert.Equal(
            [AlertFixtures.Wanted(AlertKind.AtDue, "2026-10-12T10:29:00")],
            WantedFor(AlertFixtures.AlertPriority(due: "2026-10-12T10:29:00")));

    [Fact]
    public void ADueInExactly30MinWantsOnlyTheAlertAtTheDue() =>
        Assert.Equal(
            [AlertFixtures.Wanted(AlertKind.AtDue, "2026-10-12T10:30:00")],
            WantedFor(AlertFixtures.AlertPriority(due: "2026-10-12T10:30:00")));

    [Fact]
    public void ADueIn30MinAndOneSecondWantsBoth() =>
        Assert.Equal(
            [
                AlertFixtures.Wanted(AlertKind.Before30m, "2026-10-12T10:00:01"),
                AlertFixtures.Wanted(AlertKind.AtDue, "2026-10-12T10:30:01"),
            ],
            WantedFor(AlertFixtures.AlertPriority(due: "2026-10-12T10:30:01")));

    [Fact]
    public void ADueInOneSecondWantsTheAlertAtTheDue() =>
        Assert.Equal(
            [AlertFixtures.Wanted(AlertKind.AtDue, "2026-10-12T10:00:01")],
            WantedFor(AlertFixtures.AlertPriority(due: "2026-10-12T10:00:01")));

    [Theory]
    [InlineData("2026-10-12T10:00:00")]
    [InlineData("2026-10-12T09:59:59")]
    [InlineData("2026-10-11T12:00:00")]
    public void ADueNowOrInThePastWantsNone(string due) =>
        Assert.Empty(WantedFor(AlertFixtures.AlertPriority(due: due)));

    [Fact]
    public void APriorityWithNoDueWantsNone() => Assert.Empty(WantedFor(AlertFixtures.AlertPriority()));

    [Fact]
    public void ADonePriorityWantsNone() =>
        Assert.Empty(WantedFor(AlertFixtures.AlertPriority(due: "2026-10-12T12:00:00", done: true)));

    [Fact]
    public void ADueChangeMovesBothAlerts() =>
        Assert.Equal(
            [
                AlertFixtures.Wanted(AlertKind.Before30m, "2026-10-13T07:45:00"),
                AlertFixtures.Wanted(AlertKind.AtDue, "2026-10-13T08:15:00"),
            ],
            WantedFor(AlertFixtures.AlertPriority(due: "2026-10-13T08:15:00")));

    [Fact]
    public void EachPriorityGetsItsOwnAlerts() =>
        Assert.Equal(
            [
                AlertFixtures.Wanted(AlertKind.Before30m, "2026-10-12T11:30:00", "p1"),
                AlertFixtures.Wanted(AlertKind.AtDue, "2026-10-12T12:00:00", "p1"),
                AlertFixtures.Wanted(AlertKind.AtDue, "2026-10-12T10:10:00", "p3"),
            ],
            WantedFor(
                AlertFixtures.AlertPriority("p1", "2026-10-12T12:00:00"),
                AlertFixtures.AlertPriority("p2"),
                AlertFixtures.AlertPriority("p3", "2026-10-12T10:10:00")));
}

public class AlertChangesTests
{
    private static readonly DateTime Now = At("2026-10-12T10:00:00");

    private static readonly PriorityAlert[] Planned =
    [
        AlertFixtures.Row("a1", AlertKind.Before30m, "2026-10-12T11:30:00"),
        AlertFixtures.Row("a2", AlertKind.AtDue, "2026-10-12T12:00:00"),
    ];

    private static AlertChanges Changes(
        IReadOnlyList<Priority> priorities,
        IEnumerable<PriorityAlert> rows,
        bool deliversAlerts = true)
    {
        var count = 0;
        return AlertPlanner.Changes(priorities, rows, Now, deliversAlerts, () => $"new-{++count}");
    }

    private static Priority Open(string? due, string id = "p1", bool done = false) =>
        AlertFixtures.AlertPriority(id, due, done);

    [Fact]
    public void ADueChangeMovesTheTwoRowsAndKeepsTheirIds()
    {
        var result = Changes([Open("2026-10-12T17:00:00")], Planned);
        var moved = new[]
        {
            AlertFixtures.Row("a1", AlertKind.Before30m, "2026-10-12T16:30:00"),
            AlertFixtures.Row("a2", AlertKind.AtDue, "2026-10-12T17:00:00"),
        };

        Assert.Equal(moved, result.Saved);
        Assert.Equal(moved, result.Scheduled);
        Assert.Empty(result.Cancelled);
    }

    [Fact]
    public void APriorityThatIsNotOpenCancelsItsRows()
    {
        var result = Changes([], Planned);

        Assert.Equal([AlertStatus.Cancelled, AlertStatus.Cancelled], result.Saved.Select(row => row.Status));
        Assert.Equal(["a1", "a2"], result.Saved.Select(row => row.Id));
        Assert.Empty(result.Scheduled);
        Assert.Equal(["a1", "a2"], result.Cancelled);
    }

    [Fact]
    public void ADonePriorityInTheListCancelsItsRows()
    {
        var result = Changes([Open("2026-10-12T12:00:00", done: true)], Planned);

        Assert.Equal(["a1", "a2"], result.Cancelled);
        Assert.Empty(result.Scheduled);
    }

    [Fact]
    public void ADueThatIsRemovedCancelsTheRows()
    {
        var result = Changes([Open(null)], Planned);

        Assert.Equal(["a1", "a2"], result.Cancelled);
        Assert.Empty(result.Scheduled);
    }

    [Fact]
    public void ADueThatMovesInside30MinCancelsTheRowBeforeAndMovesTheRowAtTheDue()
    {
        var result = Changes([Open("2026-10-12T10:20:00")], Planned);

        Assert.Equal(
            [Planned[0] with { Status = AlertStatus.Cancelled }, AlertFixtures.Row("a2", AlertKind.AtDue, "2026-10-12T10:20:00")],
            result.Saved);
        Assert.Equal(["a2"], result.Scheduled.Select(row => row.Id));
        Assert.Equal(["a1"], result.Cancelled);
    }

    [Fact]
    public void AScheduledRowWithAPastFireTimeBecomesDelivered()
    {
        var rows = new[]
        {
            AlertFixtures.Row("a1", AlertKind.Before30m, "2026-10-12T09:30:00"),
            AlertFixtures.Row("a2", AlertKind.AtDue, "2026-10-12T10:00:00"),
            AlertFixtures.Row("a3", AlertKind.AtDue, "2026-10-12T10:00:01", "p2"),
        };
        var result = Changes([Open("2026-10-12T10:00:00"), Open("2026-10-12T10:00:01", "p2")], rows);

        Assert.Equal(["a1", "a2"], result.Saved.Select(row => row.Id));
        Assert.Equal([AlertStatus.Delivered, AlertStatus.Delivered], result.Saved.Select(row => row.Status));
        Assert.Equal(["a3"], result.Scheduled.Select(row => row.Id));
        Assert.Empty(result.Cancelled);
    }

    [Fact]
    public void WithNoPermissionAPastRowBecomesCancelled()
    {
        var rows = new[] { AlertFixtures.Row("a1", AlertKind.Before30m, "2026-10-12T09:30:00") };
        var result = Changes([Open("2026-10-12T10:00:00")], rows, deliversAlerts: false);

        Assert.Equal([AlertStatus.Cancelled], result.Saved.Select(row => row.Status));
        Assert.Equal(["a1"], result.Cancelled);
    }

    [Fact]
    public void ADueThatMovesLaterAfterTheFirstAlertPlansANewAlertBefore()
    {
        var rows = new[]
        {
            AlertFixtures.Row("a1", AlertKind.Before30m, "2026-10-12T09:45:00", status: AlertStatus.Delivered),
            AlertFixtures.Row("a2", AlertKind.AtDue, "2026-10-12T10:15:00"),
        };
        var result = Changes([Open("2026-10-12T15:00:00")], rows);

        Assert.Equal(
            [
                AlertFixtures.Row("a2", AlertKind.AtDue, "2026-10-12T15:00:00"),
                AlertFixtures.Row("new-1", AlertKind.Before30m, "2026-10-12T14:30:00"),
            ],
            result.Saved);
        Assert.Equal(["a2", "new-1"], result.Scheduled.Select(row => row.Id));
    }

    [Fact]
    public void ASecondScheduledRowOfTheSameKindIsCancelled()
    {
        var rows = Planned.Append(AlertFixtures.Row("a3", AlertKind.AtDue, "2026-10-12T12:00:00"));
        var result = Changes([Open("2026-10-12T12:00:00")], rows);

        Assert.Equal(["a3"], result.Saved.Select(row => row.Id));
        Assert.Equal(["a3"], result.Cancelled);
        Assert.Equal(["a1", "a2"], result.Scheduled.Select(row => row.Id));
    }

    [Fact]
    public void ASnoozeStaysWhileItsPriorityIsOpenWithADue()
    {
        var snooze = AlertFixtures.Row("s1", AlertKind.Snooze, "2026-10-12T10:15:00");
        var result = Changes([Open("2026-10-12T09:50:00")], [snooze]);

        Assert.Empty(result.Saved);
        Assert.Equal([snooze], result.Scheduled);
        Assert.Empty(result.Cancelled);
    }

    [Fact]
    public void ASnoozeIsCancelledWhenItsPriorityIsDoneOrGoneOrHasNoDue()
    {
        var snooze = AlertFixtures.Row("s1", AlertKind.Snooze, "2026-10-12T10:15:00");

        Assert.Equal(["s1"], Changes([], [snooze]).Cancelled);
        Assert.Equal(["s1"], Changes([Open("2026-10-12T09:50:00", done: true)], [snooze]).Cancelled);
        Assert.Equal(["s1"], Changes([Open(null)], [snooze]).Cancelled);
    }

    [Fact]
    public void ASnoozeWithAPastFireTimeBecomesDelivered()
    {
        var snooze = AlertFixtures.Row("s1", AlertKind.Snooze, "2026-10-12T10:00:00");
        var result = Changes([Open("2026-10-12T09:50:00")], [snooze]);

        Assert.Equal([AlertStatus.Delivered], result.Saved.Select(row => row.Status));
        Assert.Empty(result.Scheduled);
    }

    [Fact]
    public void ASnoozeDoesNotTakeThePlaceOfAWantedAlert()
    {
        var snooze = AlertFixtures.Row("s1", AlertKind.Snooze, "2026-10-12T10:15:00");
        var result = Changes([Open("2026-10-12T12:00:00")], [snooze]);

        Assert.Equal([AlertKind.Before30m, AlertKind.AtDue], result.Saved.Select(row => row.Kind));
        Assert.Equal(["s1", "new-1", "new-2"], result.Scheduled.Select(row => row.Id));
    }

    [Fact]
    public void TheChangesAppliedToTheRowsGiveNoChangeTheSecondTime()
    {
        var priorities = new[] { Open("2026-10-12T17:00:00"), Open("2026-10-12T10:10:00", "p2") };
        var rows = Planned.Append(AlertFixtures.Row("a3", AlertKind.AtDue, "2026-10-12T09:00:00", "p2")).ToList();
        var first = Changes(priorities, rows);

        var after = rows.ToDictionary(row => row.Id);
        foreach (var row in first.Saved)
        {
            after[row.Id] = row;
        }

        var second = Changes(priorities, after.Values.OrderBy(row => row.Id, StringComparer.Ordinal));

        Assert.Empty(second.Saved);
        Assert.Empty(second.Cancelled);
        Assert.Equal(first.Scheduled.Select(row => row.Id).Order(), second.Scheduled.Select(row => row.Id).Order());
        Assert.Equal(["a1", "a2", "new-1"], second.Scheduled.Select(row => row.Id).Order());
    }

    [Fact]
    public void ADueWithNoRowAddsTheTwoRows()
    {
        var result = Changes([Open("2026-10-12T12:00:00")], []);
        var expected = new[]
        {
            AlertFixtures.Row("new-1", AlertKind.Before30m, "2026-10-12T11:30:00"),
            AlertFixtures.Row("new-2", AlertKind.AtDue, "2026-10-12T12:00:00"),
        };

        Assert.Equal(expected, result.Saved);
        Assert.Equal(expected, result.Scheduled);
    }

    [Fact]
    public void RowsThatMatchThePlanGiveNoChange()
    {
        var result = Changes([Open("2026-10-12T12:00:00")], Planned);

        Assert.Empty(result.Saved);
        Assert.Equal(Planned, result.Scheduled);
    }

    [Fact]
    public void OnlyTheMissingKindIsAdded()
    {
        var rows = new[] { AlertFixtures.Row("a2", AlertKind.AtDue, "2026-10-12T12:00:00") };
        var result = Changes([Open("2026-10-12T12:00:00")], rows);

        Assert.Equal([AlertFixtures.Row("new-1", AlertKind.Before30m, "2026-10-12T11:30:00")], result.Saved);
        Assert.Equal(["a2", "new-1"], result.Scheduled.Select(row => row.Id));
    }

    [Fact]
    public void ARowThatIsNotScheduledDoesNotCountAsPlanned()
    {
        var rows = new[]
        {
            AlertFixtures.Row("a1", AlertKind.Before30m, "2026-10-12T11:30:00", status: AlertStatus.Cancelled),
            AlertFixtures.Row("a2", AlertKind.AtDue, "2026-10-12T12:00:00", status: AlertStatus.Delivered),
        };
        var result = Changes([Open("2026-10-12T12:00:00")], rows);

        Assert.Equal(["new-1", "new-2"], result.Saved.Select(row => row.Id));
        Assert.Equal(["new-1", "new-2"], result.Scheduled.Select(row => row.Id));
    }

    [Fact]
    public void WithoutAnIdFactoryTheNewRowsGetDistinctIds()
    {
        var result = AlertPlanner.Changes([Open("2026-10-12T12:00:00")], [], Now);

        Assert.Equal(2, result.Saved.Select(row => row.Id).Distinct().Count());
    }
}
