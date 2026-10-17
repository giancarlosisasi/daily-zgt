using DailyZGT.Core.Domain;
using DailyZGT.Core.Rules;
using static DailyZGT.Core.Tests.Rules.RuleFixtures;

namespace DailyZGT.Core.Tests.Rules;

public class PanelLabelsTests
{
    [Theory]
    [InlineData("2026-10-12T09:00:00", "Lunes 12 oct")]
    [InlineData("2026-10-18T23:30:00", "Domingo 18 oct")]
    [InlineData("2026-12-02T08:00:00", "Miércoles 2 dic")]
    [InlineData("2026-01-01T08:00:00", "Jueves 1 ene")]
    [InlineData("2026-10-13T08:00:00", "Martes 13 oct")]
    public void DayLabelNamesTheWeekdayTheDayAndTheMonth(string date, string label) =>
        Assert.Equal(label, PanelLabels.Date(PriorityList.Today, At(date)));

    [Theory]
    [InlineData("2026-10-12T09:00:00", "Semana 42 · 12–18 oct")]
    [InlineData("2026-10-18T23:30:00", "Semana 42 · 12–18 oct")]
    [InlineData("2026-10-19T00:00:00", "Semana 43 · 19–25 oct")]
    public void WeekLabelGivesTheIsoWeekAndTheRangeFromMondayToSunday(string date, string label) =>
        Assert.Equal(label, PanelLabels.Date(PriorityList.Week, At(date)));

    [Fact]
    public void WeekLabelShowsBothMonthsWhenTheWeekCrossesTwo() =>
        Assert.Equal("Semana 40 · 28 sep–4 oct", PanelLabels.Date(PriorityList.Week, At("2026-09-30T10:00:00")));

    [Fact]
    public void WeekLabelUsesTheIsoWeekOfTheYearBoundary()
    {
        Assert.Equal("Semana 53 · 28 dic–3 ene", PanelLabels.Date(PriorityList.Week, At("2026-12-31T10:00:00")));
        Assert.Equal("Semana 53 · 28 dic–3 ene", PanelLabels.Date(PriorityList.Week, At("2027-01-01T10:00:00")));
    }

    [Fact]
    public void ScopeTabsCarryTheOpenCount()
    {
        Assert.Equal("Hoy · 3", PanelLabels.ScopeTab(PriorityList.Today, 3));
        Assert.Equal("Semana · 0", PanelLabels.ScopeTab(PriorityList.Week, 0));
    }
}

public class PanelSummaryRuleTests
{
    private static Priority Done(string id, string at, PriorityList list = PriorityList.Today) =>
        MakePriority(id, done: at, list: list);

    private static Priority Open(string id, PriorityList list = PriorityList.Today) =>
        MakePriority(id, list: list);

    [Fact]
    public void TheDayCountStartsAtLocalMidnight()
    {
        var done = new[]
        {
            Done("before", "2026-10-12T23:59:59"),
            Done("midnight", "2026-10-13T00:00:00"),
            Done("morning", "2026-10-13T08:00:00"),
        };

        Assert.Equal(
            "2 de 3 hechas hoy",
            PanelLabels.Summary(PriorityList.Today, [Open("open")], done, At("2026-10-13T09:00:00")));
    }

    [Fact]
    public void ADayChangeMovesTheDonePrioritiesOutOfTheCount()
    {
        var done = new[] { Done("morning", "2026-10-12T08:00:00") };
        var open = new[] { Open("open") };

        Assert.Equal("1 de 2 hechas hoy", PanelLabels.Summary(PriorityList.Today, open, done, At("2026-10-12T23:59:59")));
        Assert.Equal("0 de 1 hechas hoy", PanelLabels.Summary(PriorityList.Today, open, done, At("2026-10-13T00:00:00")));
    }

    [Fact]
    public void TheWeekCountStartsOnTheIsoMonday()
    {
        var done = new[]
        {
            Done("sunday", "2026-10-11T23:59:59", PriorityList.Week),
            Done("monday", "2026-10-12T00:00:00", PriorityList.Week),
            Done("friday", "2026-10-16T12:00:00", PriorityList.Week),
        };

        Assert.Equal(
            "2 de 3 hechas esta semana",
            PanelLabels.Summary(PriorityList.Week, [Open("open", PriorityList.Week)], done, At("2026-10-17T09:00:00")));
    }

    [Fact]
    public void TheWeekCountEndsAtTheSundayNight()
    {
        var done = new[] { Done("monday", "2026-10-12T09:00:00", PriorityList.Week) };

        Assert.Equal("1 de 1 hechas esta semana", PanelLabels.Summary(PriorityList.Week, [], done, At("2026-10-18T23:59:59")));
        Assert.Equal("0 de 0 hechas esta semana", PanelLabels.Summary(PriorityList.Week, [], done, At("2026-10-19T00:00:00")));
    }

    [Fact]
    public void TheWeekCountCrossesAMonthBoundary()
    {
        var done = new[]
        {
            Done("tuesday", "2026-09-29T10:00:00", PriorityList.Week),
            Done("previous-sunday", "2026-09-27T10:00:00", PriorityList.Week),
        };

        Assert.Equal("1 de 1 hechas esta semana", PanelLabels.Summary(PriorityList.Week, [], done, At("2026-10-02T09:00:00")));
    }

    [Fact]
    public void TheCountDoesNotGrowWithTheHistory()
    {
        var done = Enumerable.Range(1, 9).Select(day => Done($"old-{day}", $"2026-10-0{day}T09:00:00")).ToList();
        done.Add(Done("today", "2026-10-13T08:00:00"));

        Assert.Equal("1 de 2 hechas hoy", PanelLabels.Summary(PriorityList.Today, [Open("open")], done, At("2026-10-13T09:00:00")));
    }

    [Fact]
    public void TheCountOfHoyAndOfSemanaAreIndependent()
    {
        var done = new[]
        {
            Done("today", "2026-10-13T08:00:00"),
            Done("week", "2026-10-13T08:30:00", PriorityList.Week),
            Done("week-again", "2026-10-13T08:40:00", PriorityList.Week),
        };
        var open = new[] { Open("open-week", PriorityList.Week) };
        var now = At("2026-10-13T09:00:00");

        Assert.Equal("1 de 1 hechas hoy", PanelLabels.Summary(PriorityList.Today, open, done, now));
        Assert.Equal("2 de 3 hechas esta semana", PanelLabels.Summary(PriorityList.Week, open, done, now));
    }

    [Fact]
    public void TheEmptyListsStillCountZeroOfZero()
    {
        var now = At("2026-10-13T09:00:00");

        Assert.Equal("0 de 0 hechas hoy", PanelLabels.Summary(PriorityList.Today, StoreSnapshot.Empty, now));
        Assert.Equal("0 de 0 hechas esta semana", PanelLabels.Summary(PriorityList.Week, StoreSnapshot.Empty, now));
    }

    [Fact]
    public void TheSnapshotOverloadCountsDoneOverDoneAndOpen()
    {
        var snapshot = StoreSnapshot.Empty with
        {
            Open = [Open("b"), Open("c"), Open("e", PriorityList.Week)],
            Done = [Done("a", "2026-10-13T08:00:00"), Done("d", "2026-10-13T08:30:00", PriorityList.Week)],
        };
        var now = At("2026-10-13T09:00:00");

        Assert.Equal("1 de 3 hechas hoy", PanelLabels.Summary(PriorityList.Today, snapshot, now));
        Assert.Equal("1 de 2 hechas esta semana", PanelLabels.Summary(PriorityList.Week, snapshot, now));
    }
}
