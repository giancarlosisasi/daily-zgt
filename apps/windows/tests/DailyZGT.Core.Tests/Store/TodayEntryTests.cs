using DailyZGT.Core.Domain;
using DailyZGT.Core.Store;
using DailyZGT.Core.Tests.Support;
using static DailyZGT.Core.Domain.PriorityEventType;

namespace DailyZGT.Core.Tests.Store;

public sealed class TodayEntryTests : IDisposable
{
    private readonly TestStore _test = new(new TestClock("2026-10-05T09:00:00"));
    private AppStore Store => _test.Store;
    private TestClock Clock => _test.Clock;

    public void Dispose() => _test.Dispose();

    private static PriorityEvent Event(PriorityEventType type, string at, long? id = null) => new(id, "p", Time.At(at), type);

    private DateTime? EnteredAt(Priority priority) => TodayEntry.EnteredAt(Store.Events(priority.Id));

    [Fact]
    public void TheEntryIsTheCreatedEventWhenThereIsNoMove() =>
        Assert.Equal(
            Time.At("2026-10-09T10:00:00"),
            TodayEntry.EnteredAt([Event(Created, "2026-10-09T10:00:00"), Event(Edited, "2026-10-10T10:00:00")]));

    [Fact]
    public void TheEntryIsTheLatestMovedEvent() =>
        Assert.Equal(
            Time.At("2026-10-07T10:00:00"),
            TodayEntry.EnteredAt([
                Event(Created, "2026-10-05T10:00:00"),
                Event(Moved, "2026-10-06T10:00:00"),
                Event(Edited, "2026-10-08T10:00:00"),
                Event(Moved, "2026-10-07T10:00:00"),
                Event(Done, "2026-10-09T10:00:00"),
            ]));

    [Fact]
    public void TheEntryIgnoresEveryOtherEventType() =>
        Assert.Equal(
            Time.At("2026-10-05T10:00:00"),
            TodayEntry.EnteredAt([
                Event(Created, "2026-10-05T10:00:00"),
                Event(Edited, "2026-10-09T10:00:00"),
                Event(SubtaskDone, "2026-10-09T11:00:00"),
                Event(Done, "2026-10-09T12:00:00"),
                Event(Restored, "2026-10-12T09:00:00"),
            ]));

    [Fact]
    public void NoEventsGiveNoEntry() => Assert.Null(TodayEntry.EnteredAt([]));

    [Fact]
    public void APriorityMadeInHoyEntersWhenItIsCreated()
    {
        Clock.Set("2026-10-09T10:00:00");
        var made = Store.Add("A");
        Assert.Equal(Time.At("2026-10-09T10:00:00"), EnteredAt(made));
    }

    [Fact]
    public void APriorityMovedToHoyEntersWithTheMove()
    {
        var made = Store.Add("A", PriorityList.Week);
        Clock.Set("2026-10-07T10:00:00");
        Store.MoveToList(made.Id, PriorityList.Today);
        Assert.Equal([Created, Moved], Store.Types(made.Id));
        Assert.Equal(Time.At("2026-10-07T10:00:00"), EnteredAt(made));
    }

    [Fact]
    public void APriorityMovedAwayAndBackEntersWithTheLastMove()
    {
        var made = Store.Add("A");
        Clock.Set("2026-10-06T10:00:00");
        Store.MoveToList(made.Id, PriorityList.Week);
        Clock.Set("2026-10-08T10:00:00");
        Store.MoveToList(made.Id, PriorityList.Today);
        Assert.Equal(Time.At("2026-10-08T10:00:00"), EnteredAt(made));
    }

    [Fact]
    public void AnEditOrASubtaskDoesNotChangeTheEntry()
    {
        var made = Store.Add("A");
        Clock.Set("2026-10-08T10:00:00");
        Store.EditTitle(made.Id, "B");
        var subtask = Store.AddSubtask(made.Id, "S")!;
        Store.ToggleSubtask(subtask.Id);
        Assert.Equal(Time.At("2026-10-05T09:00:00"), EnteredAt(made));
    }

    [Fact]
    public void ARestoredPriorityKeepsItsEntry()
    {
        var made = Store.Add("A");
        Store.MarkDone(made.Id);
        Clock.Set("2026-10-09T10:00:00");
        Store.Restore(made.Id);
        Assert.Equal(Time.At("2026-10-05T09:00:00"), EnteredAt(made));
    }

    [Fact]
    public void ADailyCopyEntersWhenItArrives()
    {
        Store.DoneDaily();
        Clock.Set("2026-10-06T07:00:00");
        var copy = Assert.Single(Store.AddRepeatCopies());
        Assert.Equal([Created], Store.Types(copy.Id));
        Assert.Equal(Time.At("2026-10-06T07:00:00"), EnteredAt(copy));
    }

    [Fact]
    public void AnOpenPriorityOfHoyStaysInHoyWhenTheDayChanges()
    {
        Clock.Set("2026-10-12T21:00:00");
        var made = Store.Add("Sigue en Hoy");
        foreach (var next in new[] { "2026-10-12T23:59:59", "2026-10-13T00:00:00", "2026-10-20T09:00:00" })
        {
            Clock.Set(next);
            Store.AddRepeatCopies();
            Assert.Equal([made.Id], Store.OpenPriorities(PriorityList.Today).Ids());
        }
    }

    [Fact]
    public void TheEnteringEventsCoverOnlyTheOpenRowsOfTheList()
    {
        var open = Store.Add("Open");
        var done = Store.Add("Done");
        var weekly = Store.Add("Week", PriorityList.Week);
        Store.MarkDone(done.Id);

        Assert.Equal([open.Id], Store.EnteringEvents(PriorityList.Today).Keys);
        Assert.Equal([weekly.Id], Store.EnteringEvents(PriorityList.Week).Keys);
    }

    [Fact]
    public void TheEnteringEventsKeepOnlyCreatedAndMoved()
    {
        var made = Store.Add("A", PriorityList.Week);
        Clock.Set("2026-10-06T10:00:00");
        Store.MoveToList(made.Id, PriorityList.Today);
        Store.EditTitle(made.Id, "B");
        Store.AddSubtask(made.Id, "S");

        var events = Store.EnteringEvents(PriorityList.Today)[made.Id];
        Assert.Equal([Created, Moved], events.Select(e => e.Type));
        Assert.Equal(Time.At("2026-10-06T10:00:00"), TodayEntry.EnteredAt(events));
    }
}
