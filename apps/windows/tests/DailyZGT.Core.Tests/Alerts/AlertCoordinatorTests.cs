using DailyZGT.Core.Alerts;
using DailyZGT.Core.Domain;
using DailyZGT.Core.Localization;
using DailyZGT.Core.Tests.Support;
using static DailyZGT.Core.Tests.Rules.RuleFixtures;

namespace DailyZGT.Core.Tests.Alerts;

public sealed class AlertCoordinatorTests : IDisposable
{
    private readonly AlertHarness _h = new();

    public void Dispose() => _h.Dispose();

    [Fact]
    public void TheStartPlansTheAlertsOfThePrioritiesThatExist()
    {
        _h.AddBrief();

        _h.Started();

        var rows = _h.Store.Alerts();
        Assert.Equal([AlertKind.Before30m, AlertKind.AtDue], rows.Select(row => row.Kind));
        Assert.Equal(rows.Select(row => row.Id).Order(), _h.Toasts.Held.Keys.Order());
        Assert.Equal(1, _h.Toasts.Starts);
    }

    [Fact]
    public void AStartTwiceHooksTheSystemOnce()
    {
        _h.Started();
        _h.Alerts.Start();

        Assert.Equal(1, _h.Toasts.Starts);
        Assert.Equal(1, _h.Toasts.PendingReads);
    }

    [Fact]
    public void ANewDuePlansItsAlerts()
    {
        _h.Started();
        Assert.Empty(_h.Store.Alerts());

        _h.AddBrief();

        Assert.Equal([AlertKind.Before30m, AlertKind.AtDue], _h.Kinds());
        Assert.Equal(2, _h.Toasts.Held.Count);
    }

    [Fact]
    public void AWriteThatSkipsTheStorePlansItsAlerts()
    {
        _h.Started();

        _h.Execute(
            """
            INSERT INTO priority (id, title, level, list, due_at, position, created_at, updated_at)
            VALUES ('p1', 'From sqlite3', 'high', 'today', '2026-10-12T12:00:00', 1,
                    '2026-10-12T09:00:00', '2026-10-12T09:00:00')
            """);

        var rows = _h.Store.Alerts();
        Assert.Equal(["p1", "p1"], rows.Select(row => row.PriorityId));
        Assert.Equal([At("2026-10-12T11:30:00"), At("2026-10-12T12:00:00")], rows.Select(row => row.FireAt));
        Assert.Equal(["From sqlite3", "From sqlite3"], _h.Toasts.Held.Values.Select(request => request.Body));
    }

    [Fact]
    public void AStoreChangeThatDoesNotTouchThePlanDoesNotReadTheSystem()
    {
        _h.AddBrief();
        _h.Started();
        var reads = _h.Toasts.PendingReads;

        _h.Store.SaveNote(NoteScope.Day, "Hablar con Ana.");
        _h.Store.Add("No due", PriorityList.Week);

        Assert.Equal(reads, _h.Toasts.PendingReads);
        Assert.Equal(2, _h.Toasts.Added.Count);
    }

    [Fact]
    public void ADueChangeInTheStoreMovesTheAlerts()
    {
        _h.Started();
        var brief = _h.AddBrief();
        var ids = _h.Store.Alerts().Select(row => row.Id).ToList();

        _h.Store.SetDue(brief.Id, At("2026-10-12T17:00:00"));

        var rows = _h.Store.Alerts();
        Assert.Equal(ids, rows.Select(row => row.Id));
        Assert.Equal([At("2026-10-12T16:30:00"), At("2026-10-12T17:00:00")], rows.Select(row => row.FireAt));
        Assert.Equal(rows.Select(row => row.FireAt), _h.Toasts.Held.Values.Select(request => request.FireAt).Order());
    }

    [Fact]
    public void DoneCancelsTheAlertsAndRestorePlansThemAgain()
    {
        _h.Started();
        var brief = _h.AddBrief();

        _h.Store.MarkDone(brief.Id);
        Assert.Equal([AlertStatus.Cancelled, AlertStatus.Cancelled], _h.Statuses());
        Assert.Empty(_h.Toasts.Held);

        _h.Store.Restore(brief.Id);
        Assert.Equal([AlertKind.Before30m, AlertKind.AtDue], _h.Store.Alerts(AlertStatus.Scheduled).Select(row => row.Kind));
        Assert.Equal(2, _h.Toasts.Held.Count);
    }

    [Fact]
    public void DeleteRemovesTheRequests()
    {
        _h.Started();
        var brief = _h.AddBrief();
        Assert.Equal(2, _h.Toasts.Held.Count);

        _h.Store.Delete(brief.Id);

        Assert.Empty(_h.Store.Alerts());
        Assert.Empty(_h.Toasts.Held);
    }

    [Fact]
    public void ADueChangeAndADoneFromAnotherConnectionMoveAndCancelTheAlerts()
    {
        _h.Started();
        _h.AddBrief();

        _h.Execute("UPDATE priority SET due_at = '2026-10-12T18:00:00'");
        Assert.Equal([At("2026-10-12T17:30:00"), At("2026-10-12T18:00:00")], _h.FireTimes());
        Assert.Equal([AlertStatus.Scheduled, AlertStatus.Scheduled], _h.Statuses());

        _h.Execute("UPDATE priority SET done_at = '2026-10-12T10:00:00'");
        Assert.Equal([AlertStatus.Cancelled, AlertStatus.Cancelled], _h.Statuses());
        Assert.Empty(_h.Toasts.Held);
    }

    [Fact]
    public void RefreshOnTheDayChangeMarksTheFiredAlertsAsDelivered()
    {
        _h.Started();
        _h.AddBrief();

        _h.Time.Set("2026-10-13T00:00:00");
        _h.Toasts.Held.Clear();
        _h.Alerts.Refresh();

        Assert.Equal([AlertStatus.Delivered, AlertStatus.Delivered], _h.Statuses());
        Assert.Equal(2, _h.Toasts.Added.Count);
    }

    [Fact]
    public void TheCoordinatorWakesOneSecondAfterTheNextFireTime()
    {
        _h.Started();
        Assert.Empty(_h.Time.Timers);

        _h.AddBrief();

        Assert.Equal([TimeSpan.FromSeconds(5401)], _h.Time.Waits);
    }

    [Fact]
    public void TheWakeMarksTheAlertAsDeliveredAndPlansTheNextWake()
    {
        _h.Started();
        _h.AddBrief();
        var rows = _h.Store.Alerts();

        _h.Time.Set("2026-10-12T11:30:01");
        _h.Toasts.Held.Remove(rows[0].Id);
        _h.Time.Timers[0].Fire();

        Assert.Equal([AlertStatus.Delivered, AlertStatus.Scheduled], _h.Statuses());
        Assert.Equal([TimeSpan.FromSeconds(5401), TimeSpan.FromSeconds(1800)], _h.Time.Waits);

        _h.Time.Set("2026-10-12T12:00:01");
        _h.Toasts.Held.Remove(rows[1].Id);
        _h.Time.Timers[1].Fire();

        Assert.Equal([AlertStatus.Delivered, AlertStatus.Delivered], _h.Statuses());
        Assert.Equal(2, _h.Time.Timers.Count);
        Assert.Equal(2, _h.Toasts.Added.Count);
    }

    [Fact]
    public void AWakeOfAnOldPlanDoesNothing()
    {
        _h.Started();
        var brief = _h.AddBrief();
        _h.Store.SetDue(brief.Id, At("2026-10-12T17:00:00"));
        Assert.Equal([TimeSpan.FromSeconds(5401), TimeSpan.FromSeconds(23401)], _h.Time.Waits);
        Assert.True(_h.Time.Timers[0].Disposed);
        var reads = _h.Toasts.PendingReads;

        _h.Time.Timers[0].Fire();

        Assert.Equal(reads, _h.Toasts.PendingReads);
    }

    [Fact]
    public void ARunWithTheSameNextFireTimePlansNoNewWake()
    {
        _h.Started();
        var brief = _h.AddBrief();

        _h.Store.EditTitle(brief.Id, "Terminar el brief hoy");
        _h.Alerts.Refresh();

        Assert.Single(_h.Time.Timers);
    }

    [Fact]
    public void AFarFireTimeWakesTheCoordinatorAfterAWeekAtMost()
    {
        _h.Started();

        _h.AddBrief(due: "2027-03-01T12:00:00");

        Assert.Equal([AlertCoordinator.WakeLimit], _h.Time.Waits);
    }

    [Fact]
    public void TwoRunsInARowDoNothingTheSecondTime()
    {
        _h.Started();
        _h.AddBrief();
        var rows = _h.Store.Alerts();
        var held = _h.Toasts.Held.ToDictionary();

        _h.Alerts.Refresh();
        _h.Alerts.Refresh();

        Assert.Equal(rows, _h.Store.Alerts());
        Assert.Equal(held, _h.Toasts.Held);
        Assert.Equal(2, _h.Toasts.Added.Count);
        Assert.Empty(_h.Toasts.RemovedPending);
    }

    [Fact]
    public void TheBellSendsOneTestAlertAFewSecondsLater()
    {
        _h.Started();

        _h.Alerts.SendTestAlert();

        var request = Assert.Single(_h.Toasts.Held).Value;
        Assert.Equal(new AlertRequest("test-alert", "Prioridad vencida", "Revisa tu lista de hoy", At("2026-10-12T10:00:05"), null), request);
        Assert.Empty(_h.Store.Alerts());
    }

    [Fact]
    public void ASecondPressReplacesTheTestAlert()
    {
        _h.Started();

        _h.Alerts.SendTestAlert();
        _h.Time.Advance(TimeSpan.FromSeconds(2));
        _h.Alerts.SendTestAlert();

        Assert.Single(_h.Toasts.Held);
        Assert.Equal(At("2026-10-12T10:00:07"), _h.Toasts.Held["test-alert"].FireAt);
    }

    [Fact]
    public void TheBellSendsNothingWhenTheAlertsAreOff()
    {
        _h.Toasts.Authorization = AlertAuthorization.Denied;
        _h.Started();

        _h.Alerts.SendTestAlert();

        Assert.Empty(_h.Toasts.Added);
        Assert.True(_h.Alerts.AlertsAreOff);
    }

    [Fact]
    public void TheBellLearnsThatTheUserTurnedTheAlertsOn()
    {
        _h.Toasts.Authorization = AlertAuthorization.Denied;
        _h.Started();
        _h.Toasts.Authorization = AlertAuthorization.Authorized;

        _h.Alerts.SendTestAlert();

        Assert.False(_h.Alerts.AlertsAreOff);
        Assert.Single(_h.Toasts.Held);
    }

    [Fact]
    public void TheTestAlertStaysWhenTheAlertsAreReconciled()
    {
        _h.Started();
        _h.Alerts.SendTestAlert();

        _h.AddBrief();

        Assert.True(_h.Toasts.Held.ContainsKey("test-alert"));
        Assert.Equal(3, _h.Toasts.Held.Count);
    }

    [Fact]
    public void TheAlertsAreNotOffBeforeTheFirstRun()
    {
        _h.Toasts.Authorization = AlertAuthorization.Denied;

        Assert.False(_h.Alerts.AlertsAreOff);
        _h.Started();
        Assert.True(_h.Alerts.AlertsAreOff);
    }

    [Fact]
    public void AnAuthorizationChangeRaisesOneEvent()
    {
        var raised = 0;
        _h.Alerts.AuthorizationChanged += (_, _) => raised++;
        _h.Started();
        Assert.Equal(0, raised);

        _h.Toasts.Authorization = AlertAuthorization.Denied;
        _h.Alerts.Refresh();
        _h.Alerts.Refresh();
        Assert.Equal(1, raised);

        _h.Toasts.Authorization = AlertAuthorization.Authorized;
        _h.Alerts.Refresh();
        Assert.Equal(2, raised);
    }

    [Fact]
    public void WithTheAlertsOffAFiredAlertIsCancelledAndNothingIsScheduled()
    {
        _h.Toasts.Authorization = AlertAuthorization.Denied;
        _h.Started();
        _h.AddBrief();
        Assert.Empty(_h.Toasts.Held);

        _h.Time.Set("2026-10-12T11:45:00");
        _h.Alerts.Refresh();

        Assert.Equal([AlertStatus.Cancelled, AlertStatus.Scheduled], _h.Statuses());
        Assert.Empty(_h.Toasts.Added);
    }

    [Fact]
    public void AFailedSystemCallIsReportedAndTheNextRunTriesAgain()
    {
        _h.Started();
        _h.Toasts.FailSchedule = true;

        _h.AddBrief();

        Assert.IsType<AlertSystemException>(Assert.Single(_h.Failures));
        Assert.Empty(_h.Toasts.Held);

        _h.Toasts.FailSchedule = false;
        _h.Store.Add("Otra", PriorityList.Week);

        Assert.Equal(2, _h.Toasts.Held.Count);
    }

    [Fact]
    public void AClosedCoordinatorIgnoresTheStoreAndItsTimers()
    {
        _h.Started();
        _h.AddBrief();
        var timer = _h.Time.Timers[0];

        _h.Alerts.Dispose();
        _h.Store.Add("Otra", PriorityList.Today, due: "2026-10-12T15:00:00");
        timer.Fire();

        Assert.True(timer.Disposed);
        Assert.Equal(2, _h.Toasts.Held.Count);
    }

    [Theory]
    [InlineData(AppLanguage.Es, "Vence en 30 min", "Prioridad vencida")]
    [InlineData(AppLanguage.En, "Due in 30 min", "Priority overdue")]
    [InlineData(AppLanguage.Pt, "Vence em 30 min", "Prioridade atrasada")]
    public void TheToastsSpeakTheLanguageOfTheApp(AppLanguage language, string before, string overdue)
    {
        using var harness = new AlertHarness(Texts.For(language)).Started();
        harness.AddBrief(title: "Brief");

        var requests = harness.Toasts.Held.Values.OrderBy(request => request.FireAt).ToList();
        Assert.Equal([before, overdue], requests.Select(request => request.Title));

        harness.Alerts.SendTestAlert();
        Assert.Equal(overdue, harness.Toasts.Held["test-alert"].Title);
    }
}
