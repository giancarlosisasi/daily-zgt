using DailyZGT.Core.Domain;
using DailyZGT.Core.Store;
using DailyZGT.Core.Tests.Support;

namespace DailyZGT.Core.Tests.Store;

public sealed class AlertRowTests : IDisposable
{
    private readonly TestStore _test = new(new TestClock("2026-10-12T10:00:00"));
    private AppStore Store => _test.Store;

    public void Dispose() => _test.Dispose();

    private static PriorityAlert Row(string id, AlertKind kind, string fireAt, string priority, AlertStatus status = AlertStatus.Scheduled) =>
        new(id, priority, kind, Time.At(fireAt), status);

    [Fact]
    public void AStoreWithNoAlertGivesAnEmptyList() => Assert.Empty(Store.Alerts());

    [Fact]
    public void SavedAlertsComeBackInTheOrderOfTheFireTime()
    {
        var priority = Store.Add("With due");
        var late = Row("a-late", AlertKind.AtDue, "2026-10-12T12:00:00", priority.Id);
        var early = Row("z-early", AlertKind.Before30m, "2026-10-12T11:30:00", priority.Id);
        Store.SaveAlerts([late, early]);
        Assert.Equal([early, late], Store.Alerts());
    }

    [Fact]
    public void TheRowIsLocalTextInTheFile()
    {
        var priority = Store.Add("With due");
        Store.SaveAlerts([Row("a1", AlertKind.AtDue, "2026-10-12T12:00:00", priority.Id)]);
        Assert.Equal(["2026-10-12T12:00:00|at_due|scheduled"], _test.Rows<string>("SELECT fire_at || '|' || kind || '|' || status FROM alert"));
    }

    [Fact]
    public void ASaveOfAnIdThatExistsChangesTheFireTimeAndTheStatus()
    {
        var priority = Store.Add("With due");
        Store.SaveAlerts([Row("a1", AlertKind.AtDue, "2026-10-12T12:00:00", priority.Id)]);
        var moved = Row("a1", AlertKind.AtDue, "2026-10-12T15:00:00", priority.Id, AlertStatus.Cancelled);
        Store.SaveAlerts([moved]);
        Assert.Equal([moved], Store.Alerts());
    }

    [Fact]
    public void AnAlertOfAPriorityThatIsGoneIsNotSaved()
    {
        var priority = Store.Add("With due");
        var kept = Row("a1", AlertKind.AtDue, "2026-10-12T12:00:00", priority.Id);
        Store.SaveAlerts([Row("a0", AlertKind.AtDue, "2026-10-12T12:00:00", "missing"), kept]);
        Assert.Equal([kept], Store.Alerts());
    }

    [Fact]
    public void TheListCanKeepOnlyOneStatus()
    {
        var priority = Store.Add("With due");
        var scheduled = Row("a1", AlertKind.AtDue, "2026-10-12T12:00:00", priority.Id);
        var delivered = Row("a2", AlertKind.Before30m, "2026-10-12T11:30:00", priority.Id, AlertStatus.Delivered);
        Store.SaveAlerts([scheduled, delivered]);
        Assert.Equal([scheduled], Store.Alerts(AlertStatus.Scheduled));
        Assert.Equal([delivered], Store.Alerts(AlertStatus.Delivered));
        Assert.Empty(Store.Alerts(AlertStatus.Snoozed));
    }

    [Fact]
    public void OneAlertIsReadByItsId()
    {
        var priority = Store.Add("With due");
        var saved = Row("a1", AlertKind.Snooze, "2026-10-12T10:15:00", priority.Id);
        Store.SaveAlerts([saved]);
        Assert.Equal(saved, Store.Alert("a1"));
        Assert.Null(Store.Alert("missing"));
    }

    [Fact]
    public void ADeletedPriorityTakesItsAlertsWithIt()
    {
        var priority = Store.Add("With due");
        Store.SaveAlerts([Row("a1", AlertKind.AtDue, "2026-10-12T12:00:00", priority.Id)]);
        Store.Delete(priority.Id);
        Assert.Empty(Store.Alerts());
    }

    [Fact]
    public void AnEmptySaveWritesNothing()
    {
        var changes = _test.Changes;
        Store.SaveAlerts([]);
        Assert.Empty(Store.Alerts());
        Assert.Equal(changes, _test.Changes);
    }
}
