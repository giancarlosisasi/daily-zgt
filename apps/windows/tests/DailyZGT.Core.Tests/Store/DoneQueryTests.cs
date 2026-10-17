using DailyZGT.Core.Domain;
using DailyZGT.Core.Store;
using DailyZGT.Core.Tests.Support;

namespace DailyZGT.Core.Tests.Store;

// The store side of F08 and F19. The 24-hour cutoff and the period start are presentation rules (Rules/),
// so these tests pass the cutoff directly: now 2026-10-13 10:00 gives the cutoff 2026-10-12 10:00.
public sealed class DoneQueryTests : IDisposable
{
    private static readonly DateTime Cutoff = Time.At("2026-10-12T10:00:00");

    private readonly TestStore _test = new(new TestClock("2026-10-12T08:00:00"));
    private AppStore Store => _test.Store;

    public void Dispose() => _test.Dispose();

    private Priority AddDone(string title, string doneAt, PriorityList list = PriorityList.Today)
    {
        var added = Store.Add(title, list);
        _test.Clock.Set(doneAt);
        return Store.MarkDone(added.Id);
    }

    [Fact]
    public void APriorityDoneAfterTheCutoffIsRecent()
    {
        var done = AddDone("A", "2026-10-12T10:01:00");
        Assert.Equal([done.Id], Store.DonePrioritiesAfter(PriorityList.Today, Cutoff).Ids());
        Assert.Empty(Store.DonePrioritiesAtOrBefore(PriorityList.Today, Cutoff));
        Assert.Equal(0, Store.DoneCountAtOrBefore(PriorityList.Today, Cutoff));
    }

    [Fact]
    public void APriorityDoneExactlyAtTheCutoffIsOlder()
    {
        var done = AddDone("A", "2026-10-12T10:00:00");
        Assert.Empty(Store.DonePrioritiesAfter(PriorityList.Today, Cutoff));
        Assert.Equal([done.Id], Store.DonePrioritiesAtOrBefore(PriorityList.Today, Cutoff).Ids());
        Assert.Equal(1, Store.DoneCountAtOrBefore(PriorityList.Today, Cutoff));
    }

    [Fact]
    public void APriorityLeavesTheRecentSetWhenTheCutoffPassesIt()
    {
        var done = AddDone("A", "2026-10-12T10:00:00");
        Assert.Equal([done.Id], Store.DonePrioritiesAfter(PriorityList.Today, Time.At("2026-10-12T09:59:59")).Ids());
        Assert.Empty(Store.DonePrioritiesAfter(PriorityList.Today, Time.At("2026-10-12T10:00:00")));
    }

    [Fact]
    public void TheQueriesFilterByListAndSkipOpenPriorities()
    {
        AddDone("Today old", "2026-10-10T09:00:00");
        AddDone("Week old", "2026-10-10T09:30:00", PriorityList.Week);
        AddDone("Today new", "2026-10-13T09:00:00");
        Store.Add("Open");

        Assert.Equal(["Today new"], Store.DonePrioritiesAfter(PriorityList.Today, Cutoff).Titles());
        Assert.Equal(["Today old"], Store.DonePrioritiesAtOrBefore(PriorityList.Today, Cutoff).Titles());
        Assert.Equal(["Week old"], Store.DonePrioritiesAtOrBefore(PriorityList.Week, Cutoff).Titles());
        Assert.Empty(Store.DonePrioritiesAfter(PriorityList.Week, Cutoff));
        Assert.Equal(1, Store.DoneCountAtOrBefore(PriorityList.Today, Cutoff));
        Assert.Equal(1, Store.DoneCountAtOrBefore(PriorityList.Week, Cutoff));
    }

    [Fact]
    public void BothSetsComeNewestFirst()
    {
        AddDone("First", "2026-10-13T08:00:00");
        AddDone("Third", "2026-10-13T09:30:00");
        AddDone("Second", "2026-10-13T09:00:00");
        AddDone("Oldest", "2026-10-08T08:00:00");
        AddDone("Newest", "2026-10-11T08:00:00");
        AddDone("Middle", "2026-10-10T08:00:00");

        Assert.Equal(["Third", "Second", "First"], Store.DonePrioritiesAfter(PriorityList.Today, Cutoff).Titles());
        Assert.Equal(["Newest", "Middle", "Oldest"], Store.DonePrioritiesAtOrBefore(PriorityList.Today, Cutoff).Titles());
    }

    [Fact]
    public void TheCountFromAStartIncludesTheStartAndNotTheSecondBefore()
    {
        AddDone("Before", "2026-10-12T23:59:59");
        AddDone("At the start", "2026-10-13T00:00:00");
        AddDone("Later", "2026-10-13T09:00:00");
        var start = Time.At("2026-10-13T00:00:00");
        Assert.Equal(2, Store.DoneCountFrom(PriorityList.Today, start));
        Assert.Equal(0, Store.DoneCountFrom(PriorityList.Week, start));
    }

    [Fact]
    public void ARestoreLowersTheCount()
    {
        var done = AddDone("A", "2026-10-13T09:00:00");
        var start = Time.At("2026-10-13T00:00:00");
        Assert.Equal(1, Store.DoneCountFrom(PriorityList.Today, start));
        Store.Restore(done.Id);
        Assert.Equal(0, Store.DoneCountFrom(PriorityList.Today, start));
    }
}
