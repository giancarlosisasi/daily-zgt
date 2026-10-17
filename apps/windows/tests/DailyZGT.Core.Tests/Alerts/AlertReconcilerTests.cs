using DailyZGT.Core.Alerts;
using DailyZGT.Core.Domain;
using static DailyZGT.Core.Tests.Rules.RuleFixtures;

namespace DailyZGT.Core.Tests.Alerts;

// A database of alert rows and a toast system in memory. Reconcile applies the plan the way the adapter will.
internal sealed class AlertWorld
{
    private int nextId;

    public DateTime Now { get; set; } = At("2026-10-12T10:00:00");
    public AlertAuthorization Authorization { get; set; } = AlertAuthorization.Authorized;
    public List<Priority> Open { get; } = [];
    public Dictionary<string, PriorityAlert> Rows { get; } = [];
    public Dictionary<string, AlertRequest> Pending { get; } = [];
    public List<AlertRequest> Added { get; } = [];
    public List<IReadOnlyList<string>> RemovedPending { get; } = [];
    public List<IReadOnlyList<string>> RemovedDelivered { get; } = [];

    public IEnumerable<PriorityAlert> RowList => Rows.Values.OrderBy(row => row.FireAt).ThenBy(row => row.Id, StringComparer.Ordinal);

    public Priority AddBrief(string due = "2026-10-12T12:00:00", string id = "p1", string title = "Terminar el brief")
    {
        var priority = MakePriority(id, due: due, title: title);
        Open.Add(priority);
        return priority;
    }

    public void Edit(string id, Func<Priority, Priority> change) =>
        Open[Open.FindIndex(priority => priority.Id == id)] = change(Open.Single(priority => priority.Id == id));

    public void Advance(int minutes) => Now = Now.AddMinutes(minutes);

    public AlertReconcilePlan Reconcile()
    {
        var plan = AlertReconciler.Plan(
            Open,
            Rows.Values.Where(row => row.Status == AlertStatus.Scheduled).OrderBy(row => row.FireAt).ThenBy(row => row.Id, StringComparer.Ordinal),
            Pending.Values.ToList(),
            Authorization,
            Now,
            () => $"row-{++nextId}");

        foreach (var row in plan.Save)
        {
            Rows[row.Id] = row;
        }

        if (plan.RemovePending.Count > 0)
        {
            RemovedPending.Add(plan.RemovePending);
            foreach (var id in plan.RemovePending)
            {
                Pending.Remove(id);
            }
        }

        if (plan.RemoveDelivered.Count > 0)
        {
            RemovedDelivered.Add(plan.RemoveDelivered);
        }

        foreach (var request in plan.Add)
        {
            Added.Add(request);
            Pending[request.Id] = request;
        }

        return plan;
    }

    public void AssertNoChangeOnTheNextRun()
    {
        var rows = RowList.ToList();
        var pending = Pending.Values.OrderBy(request => request.Id, StringComparer.Ordinal).ToList();
        var added = Added.Count;
        var removedPending = RemovedPending.Count;
        var removedDelivered = RemovedDelivered.Count;

        Reconcile();

        Assert.Equal(rows, RowList.ToList());
        Assert.Equal(pending, Pending.Values.OrderBy(request => request.Id, StringComparer.Ordinal).ToList());
        Assert.Equal(added, Added.Count);
        Assert.Equal(removedPending, RemovedPending.Count);
        Assert.Equal(removedDelivered, RemovedDelivered.Count);
    }
}

public class AlertReconcilerTests
{
    [Fact]
    public void ADuePlansTwoRowsAndTwoRequests()
    {
        var world = new AlertWorld();
        world.AddBrief();

        world.Reconcile();

        var rows = world.RowList.ToList();
        Assert.Equal([AlertKind.Before30m, AlertKind.AtDue], rows.Select(row => row.Kind));
        Assert.Equal([At("2026-10-12T11:30:00"), At("2026-10-12T12:00:00")], rows.Select(row => row.FireAt));
        Assert.All(rows, row => Assert.Equal(AlertStatus.Scheduled, row.Status));
        Assert.Equal(
            new AlertRequest(rows[0].Id, "Vence en 30 min", "Terminar el brief", At("2026-10-12T11:30:00"), "p1"),
            world.Pending[rows[0].Id]);
        Assert.Equal(
            new AlertRequest(rows[1].Id, "Prioridad vencida", "Terminar el brief", At("2026-10-12T12:00:00"), "p1"),
            world.Pending[rows[1].Id]);
        Assert.Equal(2, world.Pending.Count);
    }

    [Fact]
    public void ADueIn29MinPlansOnlyTheAlertAtTheDue()
    {
        var world = new AlertWorld();
        world.AddBrief("2026-10-12T10:29:00");

        world.Reconcile();

        Assert.Equal([AlertKind.AtDue], world.RowList.Select(row => row.Kind));
        Assert.Single(world.Pending);
    }

    [Fact]
    public void APriorityWithNoDuePlansNothing()
    {
        var world = new AlertWorld();
        world.Open.Add(MakePriority("p1"));

        world.Reconcile();

        Assert.Empty(world.Rows);
        Assert.Empty(world.Added);
    }

    [Fact]
    public void TheSecondRunDoesNothing()
    {
        var world = new AlertWorld();
        world.AddBrief();

        world.Reconcile();
        world.AssertNoChangeOnTheNextRun();

        Assert.Equal(2, world.Added.Count);
        Assert.Empty(world.RemovedPending);
        Assert.Empty(world.RemovedDelivered);
    }

    [Fact]
    public void ADueChangeMovesTheRowsAndTheRequests()
    {
        var world = new AlertWorld();
        world.AddBrief();
        world.Reconcile();
        var before = world.Rows.Keys.ToHashSet();

        world.Edit("p1", priority => priority with { DueAt = At("2026-10-12T17:00:00") });
        world.Reconcile();

        var rows = world.RowList.ToList();
        Assert.Equal(before, rows.Select(row => row.Id).ToHashSet());
        Assert.Equal([AlertKind.Before30m, AlertKind.AtDue], rows.Select(row => row.Kind));
        Assert.Equal([At("2026-10-12T16:30:00"), At("2026-10-12T17:00:00")], rows.Select(row => row.FireAt));
        Assert.Equal(At("2026-10-12T16:30:00"), world.Pending[rows[0].Id].FireAt);
        Assert.Equal(At("2026-10-12T17:00:00"), world.Pending[rows[1].Id].FireAt);
        Assert.Equal(2, world.Pending.Count);
        world.AssertNoChangeOnTheNextRun();
    }

    [Fact]
    public void ADueThatMovesInside30MinCancelsTheAlertBefore()
    {
        var world = new AlertWorld();
        world.AddBrief();
        world.Reconcile();

        world.Edit("p1", priority => priority with { DueAt = At("2026-10-12T10:20:00") });
        world.Reconcile();

        var rows = world.RowList.ToList();
        Assert.Equal([AlertKind.AtDue, AlertKind.Before30m], rows.Select(row => row.Kind));
        Assert.Equal([AlertStatus.Scheduled, AlertStatus.Cancelled], rows.Select(row => row.Status));
        Assert.Equal(At("2026-10-12T10:20:00"), rows[0].FireAt);
        Assert.Equal([rows[0].Id], world.Pending.Keys);
        world.AssertNoChangeOnTheNextRun();
    }

    [Fact]
    public void ADueThatIsRemovedCancelsTheAlerts()
    {
        var world = new AlertWorld();
        world.AddBrief();
        world.Reconcile();

        world.Edit("p1", priority => priority with { DueAt = null });
        world.Reconcile();

        Assert.All(world.Rows.Values, row => Assert.Equal(AlertStatus.Cancelled, row.Status));
        Assert.Empty(world.Pending);
        world.AssertNoChangeOnTheNextRun();
    }

    [Fact]
    public void DoneCancelsTheAlertsAndRestorePlansThemAgain()
    {
        var world = new AlertWorld();
        var brief = world.AddBrief();
        world.Reconcile();
        var first = world.Rows.Keys.Order(StringComparer.Ordinal).ToList();

        world.Open.Clear();
        world.Reconcile();

        Assert.All(world.Rows.Values, row => Assert.Equal(AlertStatus.Cancelled, row.Status));
        Assert.Empty(world.Pending);
        Assert.Equal([first], world.RemovedPending);
        Assert.Equal([first], world.RemovedDelivered);
        world.AssertNoChangeOnTheNextRun();

        world.Open.Add(brief);
        world.Reconcile();

        var scheduled = world.RowList.Where(row => row.Status == AlertStatus.Scheduled).ToList();
        Assert.Equal([AlertKind.Before30m, AlertKind.AtDue], scheduled.Select(row => row.Kind));
        Assert.Empty(scheduled.Select(row => row.Id).Intersect(first));
        Assert.Equal(2, world.Rows.Values.Count(row => row.Status == AlertStatus.Cancelled));
        Assert.Equal(scheduled.Select(row => row.Id).ToHashSet(), world.Pending.Keys.ToHashSet());
        world.AssertNoChangeOnTheNextRun();
    }

    [Fact]
    public void AScheduledRowWithAPastFireTimeBecomesDelivered()
    {
        var world = new AlertWorld();
        world.AddBrief();
        world.Reconcile();
        var rows = world.RowList.ToList();

        world.Advance(95);
        world.Pending.Remove(rows[0].Id);
        world.Reconcile();

        Assert.Equal([AlertStatus.Delivered, AlertStatus.Scheduled], world.RowList.Select(row => row.Status));
        Assert.Empty(world.RemovedDelivered);
        Assert.Equal([rows[1].Id], world.Pending.Keys);
        world.AssertNoChangeOnTheNextRun();

        world.Advance(30);
        world.Pending.Remove(rows[1].Id);
        world.Reconcile();

        Assert.Equal([AlertStatus.Delivered, AlertStatus.Delivered], world.RowList.Select(row => row.Status));
        Assert.Equal(2, world.Added.Count);
        world.AssertNoChangeOnTheNextRun();
    }

    [Fact]
    public void WithNoPermissionARowWithAPastFireTimeBecomesCancelled()
    {
        var world = new AlertWorld { Authorization = AlertAuthorization.Denied };
        world.AddBrief();
        world.Reconcile();

        world.Advance(95);
        world.Reconcile();

        Assert.Equal([AlertStatus.Cancelled, AlertStatus.Scheduled], world.RowList.Select(row => row.Status));
        Assert.Empty(world.Added);
        world.AssertNoChangeOnTheNextRun();
    }

    [Fact]
    public void ARequestThatTheTableDoesNotHaveIsRemovedAndTheTestAlertStays()
    {
        var world = new AlertWorld();
        world.AddBrief();
        world.Pending["unknown"] = new AlertRequest("unknown", "Prioridad vencida", "Old", At("2026-10-12T13:00:00"), "gone");
        world.Pending[AlertRequest.TestId] = AlertRequest.Test(At("2026-10-12T10:00:05"));

        world.Reconcile();

        Assert.Equal([["unknown"]], world.RemovedPending);
        Assert.Empty(world.RemovedDelivered);
        Assert.DoesNotContain("unknown", world.Pending.Keys);
        Assert.Contains(AlertRequest.TestId, world.Pending.Keys);
        Assert.Equal(3, world.Pending.Count);
        world.AssertNoChangeOnTheNextRun();
    }

    [Fact]
    public void WithNoPermissionTheRowsStayAsThePlanAndNoRequestIsAdded()
    {
        var world = new AlertWorld { Authorization = AlertAuthorization.Denied };
        world.AddBrief();

        Assert.Equal(AlertAuthorization.Denied, world.Reconcile().Authorization);
        Assert.All(world.Rows.Values, row => Assert.Equal(AlertStatus.Scheduled, row.Status));
        Assert.Empty(world.Added);

        world.Authorization = AlertAuthorization.Authorized;
        Assert.Equal(AlertAuthorization.Authorized, world.Reconcile().Authorization);
        Assert.Equal(world.Rows.Keys.ToHashSet(), world.Pending.Keys.ToHashSet());
    }

    [Fact]
    public void TheResultHasTheNextFireTimeOfTheScheduledRows()
    {
        var world = new AlertWorld();
        Assert.Null(world.Reconcile().NextFireAt);

        world.AddBrief();
        world.AddBrief("2026-10-12T18:00:00", "p2", "Later");
        Assert.Equal(At("2026-10-12T11:30:00"), world.Reconcile().NextFireAt);

        world.Advance(95);
        Assert.Equal(At("2026-10-12T12:00:00"), world.Reconcile().NextFireAt);

        world.Open.RemoveAll(priority => priority.Id == "p1");
        Assert.Equal(At("2026-10-12T17:30:00"), world.Reconcile().NextFireAt);
    }

    [Fact]
    public void ARequestThatTheSystemLostIsAddedAgain()
    {
        var world = new AlertWorld();
        world.AddBrief();
        world.Reconcile();
        var rows = world.RowList.ToList();

        world.Pending.Remove(rows[0].Id);
        world.Reconcile();

        Assert.Equal(rows, world.RowList.ToList());
        Assert.Equal(rows.Select(row => row.Id).ToHashSet(), world.Pending.Keys.ToHashSet());
        Assert.Equal(3, world.Added.Count);
    }

    [Fact]
    public void ATitleChangeReplacesTheBodyOfTheRequests()
    {
        var world = new AlertWorld();
        world.AddBrief();
        world.Reconcile();

        world.Edit("p1", priority => priority with { Title = "Terminar el brief de Tailwind v4" });
        world.Reconcile();

        Assert.Equal(
            ["Terminar el brief de Tailwind v4", "Terminar el brief de Tailwind v4"],
            world.Pending.Values.Select(request => request.Body));
        Assert.Equal(2, world.Pending.Count);
        Assert.Equal(2, world.Rows.Count);
    }

    [Fact]
    public void ASnoozeRowGetsARequestWithTheMinutesThatAreLeft()
    {
        var world = new AlertWorld();
        world.AddBrief("2026-10-12T10:50:00");
        world.Reconcile();
        var snooze = new PriorityAlert("s1", "p1", AlertKind.Snooze, At("2026-10-12T10:15:00"), AlertStatus.Scheduled);
        world.Rows[snooze.Id] = snooze;

        world.Reconcile();

        Assert.Equal("Vence en 35 min", world.Pending["s1"].Title);
        world.AssertNoChangeOnTheNextRun();
    }

    [Fact]
    public void APlanOfAnInSyncWorldIsEmpty()
    {
        var world = new AlertWorld();
        world.AddBrief();
        world.Reconcile();

        var plan = AlertReconciler.Plan(world.Open, world.Rows.Values, world.Pending.Values, AlertAuthorization.Authorized, world.Now);

        Assert.Empty(plan.Save);
        Assert.Empty(plan.Add);
        Assert.Empty(plan.RemovePending);
        Assert.Empty(plan.RemoveDelivered);
    }
}
