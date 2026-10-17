using DailyZGT.Core.Domain;
using DailyZGT.Core.Rules;
using static DailyZGT.Core.Tests.Rules.Languages;
using static DailyZGT.Core.Tests.Rules.RuleFixtures;

namespace DailyZGT.Core.Tests.Rules;

public class ListSectionsTests
{
    private static readonly DateTime Now = At("2026-10-13T10:00:00");

    private static StoreSnapshot Snapshot(IReadOnlyList<Priority>? open = null, IReadOnlyList<Priority>? done = null) =>
        StoreSnapshot.Empty with { Open = open ?? [], Done = done ?? [] };

    [Fact]
    public void AListWithOpenPrioritiesHasNoEmptyState()
    {
        var sections = ListSections.Of(
            PriorityList.Today,
            Snapshot(open: [MakePriority("a")], done: [MakePriority("b", done: "2026-10-13T09:00:00")]),
            Now);

        Assert.Equal(EmptyList.None, sections.Empty);
    }

    [Fact]
    public void AListWithOnlyARecentDonePriorityIsAllDone()
    {
        var sections = ListSections.Of(PriorityList.Today, Snapshot(done: [MakePriority("a", done: "2026-10-12T10:00:01")]), Now);

        Assert.Equal(EmptyList.AllDone, sections.Empty);
        Assert.True(sections.ShowsDone);
        Assert.Equal("Hechas (1)", sections.DoneHeader(Es));
        Assert.Equal(0, sections.HistoryCount);
    }

    [Fact]
    public void WhenEveryDonePriorityIsOlderThan24HoursTheSectionShowsHechas0AndTheListHasNothingPending()
    {
        var sections = ListSections.Of(
            PriorityList.Today,
            Snapshot(done: [MakePriority("a", done: "2026-10-12T10:00:00"), MakePriority("b", done: "2026-10-10T18:00:00")]),
            Now);

        Assert.Equal(EmptyList.NothingPending, sections.Empty);
        Assert.True(sections.ShowsDone);
        Assert.Equal("Hechas (0)", sections.DoneHeader(Es));
        Assert.Empty(sections.RecentDone);
        Assert.Equal(2, sections.HistoryCount);
    }

    [Fact]
    public void AListWithNoPrioritiesHasNothingPendingAndNoDoneSection()
    {
        var sections = ListSections.Of(PriorityList.Today, Snapshot(), Now);

        Assert.Equal(EmptyList.NothingPending, sections.Empty);
        Assert.False(sections.ShowsDone);
        Assert.Equal(0, sections.HistoryCount);
    }

    [Fact]
    public void HechasCountsTheLast24HoursAndHistorialCountsTheRest()
    {
        var sections = ListSections.Of(
            PriorityList.Today,
            Snapshot(done:
            [
                MakePriority("recent", done: "2026-10-13T08:00:00"),
                MakePriority("edge", done: "2026-10-12T10:00:01"),
                MakePriority("old", done: "2026-10-12T10:00:00"),
                MakePriority("older", done: "2026-10-01T10:00:00"),
                MakePriority("oldest", done: "2026-09-01T10:00:00"),
            ]),
            Now);

        Assert.Equal("Hechas (2)", sections.DoneHeader(Es));
        Assert.Equal(3, sections.HistoryCount);
    }

    [Fact]
    public void TheMostRecentDonePriorityComesFirst()
    {
        var sections = ListSections.Of(
            PriorityList.Today,
            Snapshot(done:
            [
                MakePriority("morning", done: "2026-10-13T08:00:00"),
                MakePriority("now", done: "2026-10-13T09:59:00"),
                MakePriority("yesterday", done: "2026-10-12T20:00:00"),
            ]),
            Now);

        Assert.Equal(["now", "morning", "yesterday"], sections.RecentDone.Select(priority => priority.Id));
    }

    [Fact]
    public void OnlyThePrioritiesOfTheListCount()
    {
        var snapshot = Snapshot(
            open: [MakePriority("week-open", list: PriorityList.Week)],
            done:
            [
                MakePriority("week-recent", done: "2026-10-13T09:00:00", list: PriorityList.Week),
                MakePriority("today-old", done: "2026-10-01T09:00:00"),
            ]);

        var today = ListSections.Of(PriorityList.Today, snapshot, Now);
        var week = ListSections.Of(PriorityList.Week, snapshot, Now);

        Assert.Equal(EmptyList.NothingPending, today.Empty);
        Assert.Equal("Hechas (0)", today.DoneHeader(Es));
        Assert.Equal(1, today.HistoryCount);
        Assert.Equal(EmptyList.None, week.Empty);
        Assert.Equal("Hechas (1)", week.DoneHeader(Es));
        Assert.Equal(0, week.HistoryCount);
    }
}
