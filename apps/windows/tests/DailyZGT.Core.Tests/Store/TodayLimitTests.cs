using DailyZGT.Core.Domain;
using DailyZGT.Core.Store;
using DailyZGT.Core.Tests.Support;
using static DailyZGT.Core.Domain.PriorityEventType;

namespace DailyZGT.Core.Tests.Store;

public sealed class TodayLimitTests : IDisposable
{
    private readonly TestStore _test = new(new TestClock("2026-10-12T10:24:00"));
    private AppStore Store => _test.Store;

    public void Dispose() => _test.Dispose();

    private List<Priority> Fill(int count, PriorityList list = PriorityList.Today) =>
        Enumerable.Range(1, count).Select(i => Store.Add($"Prioridad {i}", list)).ToList();

    private void TurnOn() => Store.SetValue(AppStateKeys.TodayLimit, true);

    [Theory]
    [InlineData(false, 5, false)]
    [InlineData(false, 6, false)]
    [InlineData(true, 0, false)]
    [InlineData(true, 4, false)]
    [InlineData(true, 5, true)]
    [InlineData(true, 6, true)]
    public void TheRuleBlocksOnlyWhenTheSettingIsOnAndTheCountIsFiveOrMore(bool isOn, int openCount, bool blocks) =>
        Assert.Equal(blocks, TodayLimit.BlocksAdd(isOn, openCount));

    [Fact]
    public void TheMessageIsTheCopyOfTheSpec() => Assert.Equal("Hoy ya tiene 5 prioridades abiertas.", TodayLimit.Message);

    [Fact]
    public void TheSettingIsOffByDefault()
    {
        Assert.False(Store.TodayLimitIsOn);
        Fill(5);
        Assert.True(Store.CanAddToToday);
        Assert.IsType<AddOutcome.Added>(Store.AddPriority("La sexta", PriorityList.Today));
        Assert.Equal(6, Store.OpenCount(PriorityList.Today));
    }

    [Fact]
    public void TheStoreAnswersWithFourAndFiveOpenPriorities()
    {
        TurnOn();
        var first = Fill(4);
        Assert.True(Store.CanAddToToday);

        Store.Add("Quinta");
        Assert.False(Store.CanAddToToday);

        Store.MarkDone(first[0].Id);
        Assert.True(Store.CanAddToToday);
        Store.Restore(first[0].Id);
        Assert.Equal(5, Store.OpenCount(PriorityList.Today));
        Assert.False(Store.CanAddToToday);
    }

    [Fact]
    public void OnlyOpenPrioritiesOfHoyCount()
    {
        TurnOn();
        Fill(5, PriorityList.Week);
        Assert.True(Store.CanAddToToday);
        var today = Fill(4);
        foreach (var priority in today.Take(2))
        {
            Store.MarkDone(priority.Id);
        }
        Store.Add("Otra");
        Assert.Equal(3, Store.OpenCount(PriorityList.Today));
        Assert.True(Store.CanAddToToday);
    }

    [Fact]
    public void AnAddToHoyAtTheLimitWritesNothing()
    {
        TurnOn();
        Fill(5);
        var events = _test.Rows<long>("SELECT COUNT(*) FROM priority_event");
        var changes = _test.Changes;

        var outcome = Store.AddPriority("Una más", PriorityList.Today, PriorityLevel.High, Time.At("2026-10-12T16:00:00"));

        Assert.IsType<AddOutcome.BlockedByTodayLimit>(outcome);
        Assert.Equal(5, Store.OpenCount(PriorityList.Today));
        Assert.Equal([5L], _test.Rows<long>("SELECT COUNT(*) FROM priority"));
        Assert.Equal(events, _test.Rows<long>("SELECT COUNT(*) FROM priority_event"));
        Assert.Equal(changes, _test.Changes);
    }

    [Fact]
    public void AnAddToHoyWithFourOpenPrioritiesWorks()
    {
        TurnOn();
        Fill(4);
        Assert.Equal("La quinta", Assert.IsType<AddOutcome.Added>(Store.AddPriority("La quinta", PriorityList.Today)).Priority.Title);
        Assert.Equal(5, Store.OpenCount(PriorityList.Today));
    }

    [Fact]
    public void AnAddToSemanaIsNeverBlocked()
    {
        TurnOn();
        Fill(5);
        var added = Assert.IsType<AddOutcome.Added>(Store.AddPriority("Para la semana", PriorityList.Week)).Priority;
        Assert.Equal(PriorityList.Week, added.List);
    }

    [Fact]
    public void AnAddWorksAgainOnceHoyHasRoom()
    {
        TurnOn();
        var today = Fill(5);
        Assert.IsType<AddOutcome.BlockedByTodayLimit>(Store.AddPriority("Una más", PriorityList.Today));

        Store.MarkDone(today[0].Id);

        Assert.True(Store.CanAddToToday);
        Assert.IsType<AddOutcome.Added>(Store.AddPriority("Una más", PriorityList.Today));
    }

    [Fact]
    public void ABlankTitleAtTheLimitIsEmptyNotBlocked()
    {
        TurnOn();
        Fill(5);
        Assert.IsType<AddOutcome.EmptyTitle>(Store.AddPriority("   ", PriorityList.Today));
    }

    [Fact]
    public void ALimitTurnedOnByAnotherWriterIsCheckedAtTheWrite()
    {
        Fill(5);
        _test.Execute("INSERT INTO app_state (key, value) VALUES ('today_limit', 'true')");
        Assert.IsType<AddOutcome.BlockedByTodayLimit>(Store.AddPriority("Una más", PriorityList.Today));
    }

    [Fact]
    public void AMoveToHoyIsBlockedAtTheLimit()
    {
        TurnOn();
        Fill(5);
        var weekly = Store.Add("De la semana", PriorityList.Week);

        Assert.IsType<MoveOutcome.BlockedByTodayLimit>(Store.MoveToList(weekly.Id, PriorityList.Today));

        Assert.Equal(PriorityList.Week, Store.Find(weekly.Id)!.List);
        Assert.Equal([Created], Store.Types(weekly.Id));
        Assert.Equal(5, Store.OpenCount(PriorityList.Today));
    }

    [Fact]
    public void AMoveToHoyWorksWithFourOpenPriorities()
    {
        TurnOn();
        Fill(4);
        var weekly = Store.Add("De la semana", PriorityList.Week);
        var moved = Assert.IsType<MoveOutcome.Moved>(Store.MoveToList(weekly.Id, PriorityList.Today)).Priority;
        Assert.Equal(PriorityList.Today, moved.List);
    }

    [Fact]
    public void AMoveToSemanaIsNeverBlocked()
    {
        TurnOn();
        var today = Fill(5);
        var moved = Assert.IsType<MoveOutcome.Moved>(Store.MoveToList(today[0].Id, PriorityList.Week)).Priority;
        Assert.Equal(PriorityList.Week, moved.List);
    }

    [Fact]
    public void AMoveIsNotBlockedWhenTheSettingIsOff()
    {
        Fill(5);
        var weekly = Store.Add("De la semana", PriorityList.Week);
        Assert.IsType<MoveOutcome.Moved>(Store.MoveToList(weekly.Id, PriorityList.Today));
    }

    [Fact]
    public void AMoveOfAMissingPriorityAtTheLimitStillThrows()
    {
        TurnOn();
        Fill(5);
        Assert.Throws<StoreException>(() => Store.MoveToList("missing", PriorityList.Today));
    }

    [Fact]
    public void RestoreGivesBackThePriorityAtTheLimit()
    {
        TurnOn();
        var today = Fill(5);
        Store.MarkDone(today[0].Id);
        Store.Add("Sexta");
        Assert.Equal(5, Store.OpenCount(PriorityList.Today));

        Store.Restore(today[0].Id);

        Assert.False(Store.Find(today[0].Id)!.IsDone);
        Assert.Equal(6, Store.OpenCount(PriorityList.Today));
    }

    [Fact]
    public void TheDailyCopyIsNotBlockedAtTheLimit()
    {
        TurnOn();
        Store.DoneDaily("Meditar");
        Fill(5);
        _test.Clock.Set("2026-10-13T07:00:00");

        Assert.Equal(["Meditar"], Store.AddRepeatCopies().Titles());
        Assert.Equal(6, Store.OpenCount(PriorityList.Today));
    }

    [Fact]
    public void TheSettingIsJsonInAppStateAndSurvivesAReopen()
    {
        TurnOn();
        Assert.True(Store.TodayLimitIsOn);
        Assert.Equal(["true"], _test.Rows<string>("SELECT value FROM app_state WHERE key = 'today_limit'"));
        Assert.True(_test.Reopen().TodayLimitIsOn);

        _test.Store.SetValue(AppStateKeys.TodayLimit, false);
        Assert.False(_test.Store.TodayLimitIsOn);
        Assert.Equal(["false"], _test.Rows<string>("SELECT value FROM app_state WHERE key = 'today_limit'"));
    }

    [Fact]
    public void CaptureAddsToHoyWithMediaAndNoDue()
    {
        Store.Add("Semana", PriorityList.Week);

        var added = Assert.IsType<AddOutcome.Added>(Store.CapturePriority("  Llamar al banco  ")).Priority;

        Assert.Equal("Llamar al banco", added.Title);
        Assert.Equal(PriorityList.Today, added.List);
        Assert.Equal(PriorityLevel.Medium, added.Level);
        Assert.Null(added.DueAt);
        Assert.Equal([added], Store.OpenPriorities(PriorityList.Today));
        Assert.Equal([Created], Store.Types(added.Id));
        Assert.Empty(Store.Alerts());
    }

    [Fact]
    public void CaptureOfABlankTitleAddsNothing()
    {
        Assert.IsType<AddOutcome.EmptyTitle>(Store.CapturePriority(" \n "));
        Assert.Empty(Store.Snapshot.Open);
    }

    [Fact]
    public void CaptureIsBlockedAtTheLimit()
    {
        TurnOn();
        Fill(5);
        Assert.IsType<AddOutcome.BlockedByTodayLimit>(Store.CapturePriority("Una más"));
        Assert.Equal([5L], _test.Rows<long>("SELECT COUNT(*) FROM priority"));
    }
}
