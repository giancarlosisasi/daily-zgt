using DailyZGT.Core.Domain;
using DailyZGT.Core.Repeat;
using DailyZGT.Core.Tests.Support;

namespace DailyZGT.Core.Tests.Repeat;

public sealed class RepeatPlannerTests
{
    private static readonly DateTime Now = Time.At("2026-10-13T09:00:00");

    private static Priority P(
        string id,
        string? series = null,
        RepeatRule rule = RepeatRule.Daily,
        string? done = null,
        string? due = null,
        string created = "2026-10-10T09:00:00",
        int position = 1,
        PriorityLevel level = PriorityLevel.Medium,
        PriorityList list = PriorityList.Today,
        string title = "Meditar",
        string note = "") =>
        new(id, title, note, level, list,
            due is null ? null : Time.At(due),
            done is null ? null : Time.At(done),
            position, Time.At(created), Time.At(done ?? created), rule, series);

    private static Subtask S(string id, string priorityId, string title, int position, bool done = false) =>
        new(id, priorityId, title, done ? Time.At("2026-10-10T09:00:00") : null, position, Time.At("2026-10-10T09:00:00"));

    private static IReadOnlyList<RepeatCopy> Copies(DateTime now, Priority[] priorities, params Subtask[] subtasks) =>
        RepeatPlanner.Copies(
            priorities,
            subtasks.GroupBy(s => s.PriorityId).ToDictionary(g => g.Key, g => (IReadOnlyList<Subtask>)g.ToList()),
            now,
            TimeZoneInfo.Utc);

    private static IReadOnlyList<RepeatCopy> Copies(params Priority[] priorities) => Copies(Now, priorities);

    [Fact]
    public void ADailyPriorityDoneYesterdayGetsOneCopyWithTheSameContent()
    {
        var source = P("p1", done: "2026-10-12T21:00:00", due: "2026-10-12T18:30:00", level: PriorityLevel.High, note: "Diez minutos.");
        var copy = Assert.Single(Copies(Now, [source],
            S("s2", "p1", "Estirar", 2),
            S("s1", "p1", "Respirar", 1, done: true),
            S("s9", "other", "De otra", 1)));

        Assert.Equal("p1", copy.SourceId);
        Assert.Equal("p1", copy.SeriesId);
        Assert.Equal("Meditar", copy.Title);
        Assert.Equal("Diez minutos.", copy.Note);
        Assert.Equal(PriorityLevel.High, copy.Level);
        Assert.Equal(Time.At("2026-10-13T18:30:00"), copy.DueAt);
        Assert.Equal(["Respirar", "Estirar"], copy.SubtaskTitles);
    }

    [Fact]
    public void APriorityDoneTodayGetsNoCopyToday()
    {
        Assert.Empty(Copies(P("p1", done: "2026-10-13T00:00:00")));
        Assert.Empty(Copies(P("p1", done: "2026-10-13T08:59:59")));
    }

    [Fact]
    public void TheLastSecondOfYesterdayIsYesterday() =>
        Assert.Equal(["p1"], Copies(P("p1", done: "2026-10-12T23:59:59")).Select(c => c.SourceId));

    [Fact]
    public void SeveralMissedDaysGiveOneCopyForToday()
    {
        var copy = Assert.Single(Copies(P("p1", done: "2026-10-05T07:00:00", due: "2026-10-05T08:15:00")));
        Assert.Equal(Time.At("2026-10-13T08:15:00"), copy.DueAt);
    }

    [Fact]
    public void ADueTimeBeforeNowStaysOnToday()
    {
        var copy = Assert.Single(Copies(Time.At("2026-10-13T20:00:00"), [P("p1", done: "2026-10-12T07:00:00", due: "2026-10-11T08:15:30")]));
        Assert.Equal(Time.At("2026-10-13T08:15:30"), copy.DueAt);
    }

    [Fact]
    public void NoDueStaysNoDue()
    {
        var copy = Assert.Single(Copies(P("p1", done: "2026-10-12T07:00:00")));
        Assert.Null(copy.DueAt);
        Assert.Empty(copy.SubtaskTitles);
    }

    [Fact]
    public void AnOpenDailyPriorityGetsNoCopy() => Assert.Empty(Copies(P("p1", created: "2026-10-01T09:00:00")));

    [Fact]
    public void ASeriesWithAnOpenCopyGetsNoCopy() =>
        Assert.Empty(Copies(
            P("p1", done: "2026-10-11T21:00:00"),
            P("p2", series: "p1", created: "2026-10-12T00:00:05", position: 2)));

    [Fact]
    public void AnOpenCopyWithTheRuleOffStillBlocksANewCopy() =>
        Assert.Empty(Copies(
            P("p1", done: "2026-10-11T21:00:00"),
            P("p2", series: "p1", rule: RepeatRule.None, created: "2026-10-12T00:00:05", position: 2)));

    [Fact]
    public void TheRuleNoneGivesNoCopy() => Assert.Empty(Copies(P("p1", rule: RepeatRule.None, done: "2026-10-12T21:00:00")));

    [Fact]
    public void TheCopyThatWasDoneLastDecidesTheRuleAndTheContent()
    {
        Assert.Empty(Copies(
            P("p1", done: "2026-10-11T21:00:00", title: "Old"),
            P("p2", series: "p1", rule: RepeatRule.None, done: "2026-10-12T21:00:00", created: "2026-10-12T00:00:05", position: 2)));

        var copy = Assert.Single(Copies(
            P("p1", rule: RepeatRule.None, done: "2026-10-11T21:00:00", title: "Old"),
            P("p2", series: "p1", done: "2026-10-12T21:00:00", created: "2026-10-12T00:00:05", position: 2, title: "New")));
        Assert.Equal("p2", copy.SourceId);
        Assert.Equal("New", copy.Title);
        Assert.Equal("p1", copy.SeriesId);
    }

    [Fact]
    public void AnOlderCopyThatWasDoneLaterIsTheSource()
    {
        Priority[] series =
        [
            P("p1", done: "2026-10-13T08:00:00", created: "2026-10-01T09:00:00"),
            P("p2", series: "p1", done: "2026-10-12T21:00:00", created: "2026-10-12T00:00:05", position: 2),
        ];
        Assert.Empty(Copies(Now, series));
        Assert.Equal(["p1"], Copies(Time.At("2026-10-14T00:00:00"), series).Select(c => c.SourceId));
    }

    [Fact]
    public void ASeriesGoesOnWhenItsFirstPriorityIsGone()
    {
        var copy = Assert.Single(Copies(
            P("p2", series: "p1", done: "2026-10-11T21:00:00", position: 2),
            P("p3", series: "p1", done: "2026-10-12T21:00:00", position: 3, title: "Third")));
        Assert.Equal("p3", copy.SourceId);
        Assert.Equal("p1", copy.SeriesId);
    }

    [Fact]
    public void EachSeriesGetsItsOwnCopyInTheOrderOfThePositions()
    {
        var copies = Copies(
            P("b", done: "2026-10-12T21:00:00", position: 7, title: "Leer"),
            P("a", done: "2026-10-12T20:00:00", position: 9, title: "Correr"),
            P("c", done: "2026-10-12T20:00:00", position: 3, list: PriorityList.Week, title: "Meditar"),
            P("d", rule: RepeatRule.None, done: "2026-10-12T20:00:00", position: 1, title: "Una vez"),
            P("e", position: 2, title: "Abierta"));
        Assert.Equal(["Meditar", "Leer", "Correr"], copies.Select(c => c.Title));
        Assert.Equal(["c", "b", "a"], copies.Select(c => c.SeriesId));
    }

    [Fact]
    public void TheCopyMakesTheSeriesNotReady()
    {
        var source = P("p1", done: "2026-10-12T21:00:00");
        var copy = Copies(source)[0];
        Assert.Empty(Copies(source, P("p2", series: copy.SeriesId, created: "2026-10-13T09:00:00", position: 2)));
    }

    [Fact]
    public void AClockThatGoesBackGivesNoCopy() =>
        Assert.Empty(Copies(Time.At("2026-10-11T09:00:00"), [P("p1", done: "2026-10-12T21:00:00")]));

    [Fact]
    public void ADueTimeThatTheZoneSkipsTodayMovesToTheFirstTimeAfterTheGap()
    {
        var newYork = TimeZoneInfo.FindSystemTimeZoneById("America/New_York");
        var moved = RepeatPlanner.SameTime(Time.At("2026-03-07T02:30:00"), Time.At("2026-03-08T09:00:00"), newYork);
        Assert.Equal(Time.At("2026-03-08T03:00:00"), moved);
        Assert.Equal(
            Time.At("2026-03-09T02:30:00"),
            RepeatPlanner.SameTime(Time.At("2026-03-07T02:30:00"), Time.At("2026-03-09T09:00:00"), newYork));
    }
}
