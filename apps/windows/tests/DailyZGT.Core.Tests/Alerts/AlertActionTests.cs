using DailyZGT.Core.Alerts;
using DailyZGT.Core.Domain;
using DailyZGT.Core.Localization;
using DailyZGT.Core.Tests.Support;
using static DailyZGT.Core.Tests.Rules.RuleFixtures;

namespace DailyZGT.Core.Tests.Alerts;

public sealed class AlertActionTests : IDisposable
{
    private readonly AlertHarness _h = new AlertHarness().Started();

    public void Dispose() => _h.Dispose();

    private (Priority Brief, IReadOnlyList<PriorityAlert> Rows) BriefWithAlerts()
    {
        var brief = _h.AddBrief(due: "2026-10-12T10:30:00", list: PriorityList.Week);
        return (brief, _h.Store.Alerts());
    }

    private void Fire(PriorityAlert alert)
    {
        _h.Time.Set(LocalTime.Text(alert.FireAt.AddMinutes(1)));
        _h.Toasts.Held.Remove(alert.Id);
        _h.Toasts.Delivered.Add(alert.Id);
    }

    private static AlertResponse Answer(AlertAction action, string alert, string? priority) => new(alert, priority, action);

    [Fact]
    public void TheStartListensToTheResponsesOfTheSystem()
    {
        Assert.True(_h.Toasts.HasListener);
        var (brief, rows) = BriefWithAlerts();

        _h.Toasts.Respond(Answer(AlertAction.Open, rows[0].Id, brief.Id));

        Assert.Equal([brief.Id], _h.Opened);
    }

    [Fact]
    public void ADisposedCoordinatorStopsListening()
    {
        _h.Alerts.Dispose();

        Assert.False(_h.Toasts.HasListener);
    }

    [Fact]
    public void OpenShowsThePriority()
    {
        var (brief, rows) = BriefWithAlerts();

        _h.Alerts.Answer(Answer(AlertAction.Open, rows[0].Id, brief.Id));

        Assert.Equal([brief.Id], _h.Opened);
        Assert.Equal(rows, _h.Store.Alerts());
    }

    [Fact]
    public void OpenOnADonePriorityDoesNothing()
    {
        var (brief, rows) = BriefWithAlerts();
        _h.Store.MarkDone(brief.Id);

        _h.Alerts.Answer(Answer(AlertAction.Open, rows[0].Id, brief.Id));

        Assert.Empty(_h.Opened);
    }

    [Fact]
    public void OpenOnAPriorityThatIsGoneDoesNothing()
    {
        var (brief, rows) = BriefWithAlerts();
        _h.Store.Delete(brief.Id);

        _h.Alerts.Answer(Answer(AlertAction.Open, rows[0].Id, brief.Id));

        Assert.Empty(_h.Opened);
    }

    [Fact]
    public void OpenOnTheTestAlertShowsThePanelWithNoPriority()
    {
        _h.Alerts.Answer(Answer(AlertAction.Open, AlertRequest.TestId, null));

        Assert.Null(Assert.Single(_h.Opened));
    }

    [Fact]
    public void SnoozeAddsOneAlertIn15MinAndSetsTheActedAlertToSnoozed()
    {
        var (brief, rows) = BriefWithAlerts();
        Assert.Equal([AlertKind.AtDue], rows.Select(row => row.Kind));

        _h.Time.Set("2026-10-12T10:31:10");
        _h.Toasts.Held.Clear();
        _h.Toasts.Delivered.Add(rows[0].Id);
        _h.Alerts.Answer(Answer(AlertAction.Snooze, rows[0].Id, brief.Id));

        var after = _h.Store.Alerts();
        Assert.Equal([AlertKind.AtDue, AlertKind.Snooze], after.Select(row => row.Kind));
        Assert.Equal([AlertStatus.Snoozed, AlertStatus.Scheduled], after.Select(row => row.Status));
        Assert.Equal(At("2026-10-12T10:46:10"), after[1].FireAt);
        Assert.Equal(brief.Id, after[1].PriorityId);
        Assert.Equal(
            new AlertRequest(after[1].Id, "Prioridad vencida", "Terminar el brief", At("2026-10-12T10:46:10"), brief.Id),
            Assert.Single(_h.Toasts.Held).Value);
        Assert.Empty(_h.Opened);
    }

    [Fact]
    public void ASnoozeBeforeTheDueSaysTheMinutesThatAreLeft()
    {
        var brief = _h.AddBrief(due: "2026-10-12T11:00:00");
        var before = _h.Store.Alerts().Single(row => row.Kind == AlertKind.Before30m);

        _h.Time.Set("2026-10-12T10:31:00");
        _h.Alerts.Answer(Answer(AlertAction.Snooze, before.Id, brief.Id));

        var snooze = _h.Store.Alerts().Single(row => row.Kind == AlertKind.Snooze);
        Assert.Equal(At("2026-10-12T10:46:00"), snooze.FireAt);
        Assert.Equal("Vence en 14 min", _h.Toasts.Held[snooze.Id].Title);
        Assert.Equal(AlertStatus.Snoozed, _h.Store.Alert(before.Id)?.Status);
        Assert.Equal([AlertKind.Snooze, AlertKind.AtDue], _h.Store.Alerts(AlertStatus.Scheduled).Select(row => row.Kind));
    }

    [Fact]
    public void TheSnoozeStaysWhenTheAlertsAreReconciledAgain()
    {
        var (brief, rows) = BriefWithAlerts();
        Fire(rows[0]);
        _h.Alerts.Answer(Answer(AlertAction.Snooze, rows[0].Id, brief.Id));
        var after = _h.Store.Alerts();
        var added = _h.Toasts.Added.Count;
        Assert.Equal([AlertStatus.Snoozed, AlertStatus.Scheduled], after.Select(row => row.Status));

        _h.Alerts.Refresh();
        _h.Store.EditTitle(brief.Id, "Terminar el brief hoy");

        Assert.Equal(after, _h.Store.Alerts());
        Assert.Equal(added + 1, _h.Toasts.Added.Count);
        Assert.Equal(["Terminar el brief hoy"], _h.Toasts.Held.Values.Select(request => request.Body));
    }

    [Fact]
    public void SnoozeOnADonePriorityDoesNothing()
    {
        var (brief, rows) = BriefWithAlerts();
        _h.Store.MarkDone(brief.Id);
        var before = _h.Store.Alerts();

        _h.Alerts.Answer(Answer(AlertAction.Snooze, rows[0].Id, brief.Id));

        Assert.Equal(before, _h.Store.Alerts());
        Assert.Empty(_h.Toasts.Held);
    }

    [Fact]
    public void SnoozeOnAPriorityThatIsGoneDoesNothing()
    {
        var (brief, rows) = BriefWithAlerts();
        _h.Store.Delete(brief.Id);

        _h.Alerts.Answer(Answer(AlertAction.Snooze, rows[0].Id, brief.Id));

        Assert.Empty(_h.Store.Alerts());
        Assert.Empty(_h.Toasts.Held);
    }

    [Fact]
    public void SnoozeOnAPriorityWithNoDueDoesNothing()
    {
        var (brief, rows) = BriefWithAlerts();
        _h.Store.SetDue(brief.Id, null);

        _h.Alerts.Answer(Answer(AlertAction.Snooze, rows[0].Id, brief.Id));

        Assert.Equal([AlertKind.AtDue], _h.Kinds());
        Assert.Equal([AlertStatus.Cancelled], _h.Statuses());
    }

    [Fact]
    public void DoneCancelsTheSnooze()
    {
        var (brief, rows) = BriefWithAlerts();
        Fire(rows[0]);
        _h.Alerts.Answer(Answer(AlertAction.Snooze, rows[0].Id, brief.Id));
        Assert.Single(_h.Toasts.Held);

        _h.Store.MarkDone(brief.Id);

        Assert.Equal([AlertKind.AtDue, AlertKind.Snooze], _h.Kinds());
        Assert.Equal([AlertStatus.Snoozed, AlertStatus.Cancelled], _h.Statuses());
        Assert.Empty(_h.Toasts.Held);
    }

    [Fact]
    public void SnoozeOnTheTestAlertSendsItAgainIn15MinWithNoRow()
    {
        _h.Alerts.Answer(Answer(AlertAction.Snooze, AlertRequest.TestId, null));

        Assert.Equal(
            AlertRequest.Test(At("2026-10-12T10:15:00"), Texts.Es),
            Assert.Single(_h.Toasts.Held).Value);
        Assert.Empty(_h.Store.Alerts());
        Assert.Empty(_h.Opened);
    }

    [Fact]
    public void ARowMovesToDeliveredWhenItsFireTimeHasPassed()
    {
        var (_, rows) = BriefWithAlerts();
        Fire(rows[0]);

        _h.Alerts.Refresh();
        Assert.Equal([AlertStatus.Delivered], _h.Statuses());

        _h.Toasts.Delivered.AddRange([AlertRequest.TestId, "missing"]);
        _h.Alerts.Refresh();
        Assert.Equal([AlertStatus.Delivered], _h.Statuses());
    }

    [Fact]
    public void AToastThatWindowsShowedAtOnceIsNotScheduledAgain()
    {
        var brief = _h.AddBrief(due: "2026-10-12T10:30:01");
        var soon = _h.Store.Alerts().Single(row => row.Kind == AlertKind.Before30m);
        Assert.Equal(At("2026-10-12T10:00:01"), soon.FireAt);
        var added = _h.Toasts.Added.Count;

        _h.Toasts.Held.Remove(soon.Id);
        _h.Toasts.Delivered.Add(soon.Id);
        _h.Alerts.Refresh();

        Assert.Equal(added, _h.Toasts.Added.Count);
        Assert.Equal([brief.Id], _h.Toasts.Held.Values.Select(request => request.PriorityId).Distinct());
    }

    [Fact]
    public void AToastThatIsStillFarAwayIsScheduledAgainEvenIfAnOldOneIsListed()
    {
        _h.AddBrief(due: "2026-10-12T10:30:01");
        var later = _h.Store.Alerts().Single(row => row.Kind == AlertKind.AtDue);
        var added = _h.Toasts.Added.Count;

        _h.Toasts.Held.Remove(later.Id);
        _h.Toasts.Delivered.Add(later.Id);
        _h.Alerts.Refresh();

        Assert.Equal(added + 1, _h.Toasts.Added.Count);
        Assert.Contains(later.Id, _h.Toasts.Held.Keys);
    }

    [Fact]
    public void ACancelledAlertThatWindowsStillListsStaysCancelled()
    {
        var (brief, rows) = BriefWithAlerts();
        _h.Store.MarkDone(brief.Id);

        _h.Toasts.Delivered.Add(rows[0].Id);
        _h.Alerts.Refresh();

        Assert.Equal([AlertStatus.Cancelled], _h.Statuses());
    }

    [Fact]
    public void DoneRemovesTheToastOfAScheduledAlertFromTheActionCenterToo()
    {
        var (brief, rows) = BriefWithAlerts();

        _h.Store.MarkDone(brief.Id);

        Assert.Equal([rows[0].Id], Assert.Single(_h.Toasts.RemovedDelivered));
        Assert.Equal([rows[0].Id], Assert.Single(_h.Toasts.RemovedPending));
    }
}
