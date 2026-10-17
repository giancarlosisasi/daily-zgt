using DailyZGT.Core.Domain;
using DailyZGT.Core.Repeat;
using DailyZGT.Core.Store;
using DailyZGT.Core.Tests.Support;
using static DailyZGT.Core.Domain.PriorityEventType;

namespace DailyZGT.Core.Tests.Repeat;

public sealed class RepeatCoordinatorTests : IDisposable
{
    private readonly TestStore _test = new(new TestClock("2026-10-12T09:00:00"));
    private AppStore Store => _test.Store;
    private TestClock Clock => _test.Clock;

    public void Dispose() => _test.Dispose();

    private RepeatCoordinator Started()
    {
        var coordinator = new RepeatCoordinator(Store);
        coordinator.Start();
        return coordinator;
    }

    [Fact]
    public void TheStartAddsTheCopyOfASeriesThatIsReady()
    {
        var source = Store.DoneDaily();
        Clock.Set("2026-10-13T07:00:00");

        using var coordinator = Started();

        var copy = Assert.Single(Store.OpenPriorities(PriorityList.Today));
        Assert.Equal("Meditar", copy.Title);
        Assert.Equal(source.Id, copy.SeriesId);
        Assert.Equal([Created], Store.Types(copy.Id));
    }

    [Fact]
    public void TheStartAddsNothingForAPriorityDoneToday()
    {
        Store.DoneDaily();
        using var coordinator = Started();
        Assert.Empty(Store.OpenPriorities(PriorityList.Today));
        Assert.Equal([1L], _test.Rows<long>("SELECT COUNT(*) FROM priority"));
    }

    [Fact]
    public void ARunOnTheNextDayAddsTheCopyAndASecondRunAddsNothing()
    {
        Store.DoneDaily(due: "2026-10-12T23:00:00");
        using var coordinator = Started();
        Assert.Empty(Store.OpenPriorities(PriorityList.Today));

        Clock.Set("2026-10-13T00:00:00");
        coordinator.Run();
        coordinator.Run();

        var copy = Assert.Single(Store.OpenPriorities(PriorityList.Today));
        Assert.Equal(Time.At("2026-10-13T23:00:00"), copy.DueAt);
        Assert.Equal([2L], _test.Rows<long>("SELECT COUNT(*) FROM priority"));
    }

    [Fact]
    public void ARunOnALaterDayAddsOneCopyMadeThatDay()
    {
        Store.DoneDaily();
        using var coordinator = Started();

        Clock.Set("2026-10-16T08:00:00");
        coordinator.Run();

        var copy = Assert.Single(Store.OpenPriorities(PriorityList.Today));
        Assert.Equal(Time.At("2026-10-16T08:00:00"), copy.CreatedAt);
    }

    [Fact]
    public void AStoreChangeThatMakesASeriesReadyAddsTheCopyAtOnce()
    {
        var plain = Store.Add("Leer");
        Store.MarkDone(plain.Id);
        Clock.Set("2026-10-13T07:00:00");
        using var coordinator = Started();
        Assert.Empty(Store.OpenPriorities(PriorityList.Today));

        Store.SetRepeat(plain.Id, RepeatRule.Daily);

        Assert.Equal(["Leer"], Store.OpenPriorities(PriorityList.Today).Titles());
        Assert.Equal([plain.Id], Store.OpenPriorities(PriorityList.Today).Select(p => p.SeriesId));
    }

    [Fact]
    public void AWriteFromAnotherProgramAddsTheCopyAfterTheCheck()
    {
        var plain = Store.Add("Leer");
        Store.MarkDone(plain.Id);
        Clock.Set("2026-10-13T07:00:00");
        using var coordinator = Started();

        _test.Execute("UPDATE priority SET repeat_rule = 'daily'");
        Store.CheckForExternalChanges();

        Assert.Equal(["Leer"], Store.OpenPriorities(PriorityList.Today).Titles());
        Assert.Equal([1L], _test.Rows<long>("SELECT COUNT(*) FROM priority WHERE done_at IS NULL"));
    }

    [Fact]
    public void AChangeThatMakesNoSeriesReadyAddsNothing()
    {
        var open = Store.AddDaily();
        using var coordinator = Started();

        Store.SaveNote(NoteScope.Day, "Hablar con Ana.");
        Store.AddSubtask(open.Id, "Respirar");
        Store.MarkDone(open.Id);

        Assert.Empty(Store.OpenPriorities(PriorityList.Today));
        Assert.Equal([1L], _test.Rows<long>("SELECT COUNT(*) FROM priority"));
    }

    [Fact]
    public void ARestoreLeavesOneOpenPriorityOfTheSeries()
    {
        var source = Store.DoneDaily();
        Clock.Set("2026-10-13T07:00:00");
        using var coordinator = Started();
        var copy = Assert.Single(Store.OpenPriorities(PriorityList.Today));

        Store.Restore(source.Id);

        Assert.Null(Store.Find(copy.Id));
        Assert.Equal([source.Id], Store.OpenPriorities(PriorityList.Today).Ids());
    }

    [Fact]
    public void DoneAndUndoOnTheSameDayAddNoCopy()
    {
        var open = Store.AddDaily();
        using var coordinator = Started();

        Store.MarkDone(open.Id);
        Assert.Empty(Store.OpenPriorities(PriorityList.Today));
        Store.Restore(open.Id);

        Assert.Equal([open.Id], Store.OpenPriorities(PriorityList.Today).Ids());
        Assert.Equal([1L], _test.Rows<long>("SELECT COUNT(*) FROM priority"));
    }

    [Fact]
    public void AfterDisposeAChangeAddsNothing()
    {
        var plain = Store.Add("Leer");
        Store.MarkDone(plain.Id);
        Clock.Set("2026-10-13T07:00:00");
        Started().Dispose();

        Store.SetRepeat(plain.Id, RepeatRule.Daily);

        Assert.Empty(Store.OpenPriorities(PriorityList.Today));
    }
}
