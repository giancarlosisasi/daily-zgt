using DailyZGT.Core.Domain;
using DailyZGT.Core.Rules;
using static DailyZGT.Core.Tests.Rules.RuleFixtures;
using static DailyZGT.Core.Tests.Rules.Languages;

namespace DailyZGT.Core.Tests.Rules;

public class DoneWindowTests
{
    private static readonly DateTime Now = At("2026-10-13T10:00:00");

    [Fact]
    public void TheWindowIs24Hours() => Assert.Equal(TimeSpan.FromHours(24), DoneWindow.Length);

    [Fact]
    public void TheCutoffIs24HoursBeforeNow() =>
        Assert.Equal(At("2026-10-12T10:00:00"), DoneWindow.Cutoff(Now));

    [Fact]
    public void TheCutoffIgnoresFractionsOfASecond() =>
        Assert.Equal(At("2026-10-12T10:00:00"), DoneWindow.Cutoff(Now.AddMilliseconds(900)));

    [Fact]
    public void ADonePriorityIsInHechasUntilExactly24HoursPass()
    {
        var doneAt = At("2026-10-13T08:00:00");
        Assert.True(DoneWindow.IsRecent(doneAt, doneAt.Add(DoneWindow.Length - TimeSpan.FromMinutes(1))));
        Assert.False(DoneWindow.IsRecent(doneAt, doneAt.Add(DoneWindow.Length)));
        Assert.True(DoneWindow.IsHistory(doneAt, doneAt.Add(DoneWindow.Length)));
    }

    [Fact]
    public void ADonePriorityOneSecondInsideTheWindowIsRecent() =>
        Assert.True(DoneWindow.IsRecent(At("2026-10-12T10:00:01"), Now));

    [Fact]
    public void TheDayPeriodStartsAtLocalMidnight() =>
        Assert.Equal(At("2026-10-13T00:00:00"), DoneWindow.PeriodStart(PriorityList.Today, At("2026-10-13T09:00:00")));

    [Theory]
    [InlineData("2026-10-12T00:00:00")]
    [InlineData("2026-10-14T13:00:00")]
    [InlineData("2026-10-18T23:59:59")]
    public void TheWeekPeriodStartsOnTheIsoMonday(string now) =>
        Assert.Equal(At("2026-10-12T00:00:00"), DoneWindow.PeriodStart(PriorityList.Week, At(now)));

    [Fact]
    public void TheWeekPeriodCrossesAMonthBoundary() =>
        Assert.Equal(At("2026-09-28T00:00:00"), DoneWindow.PeriodStart(PriorityList.Week, At("2026-10-02T09:00:00")));
}

public class DoneHistoryTests
{
    private static readonly DateTime Now = At("2026-10-13T10:00:00");

    private static Priority Done(string id, string title, string doneAt, int position = 1) =>
        MakePriority(id, title: title, done: doneAt, position: position);

    [Fact]
    public void TheGroupsFollowTheLocalDayNewestFirst()
    {
        var groups = DoneHistory.Groups(
        [
            Done("a", "Pagar el hosting", "2026-10-08T17:30:00"),
            Done("b", "Enviar la factura", "2026-10-08T09:10:00"),
            Done("c", "Responder a Ana", "2026-10-12T08:45:00"),
            Done("d", "Revisar el MR", "2026-10-12T09:20:00"),
        ]);

        Assert.Equal(["2026-10-12", "2026-10-08"], groups.Select(group => group.Day));
        Assert.Equal(["Revisar el MR", "Responder a Ana"], groups[0].Priorities.Select(priority => priority.Title));
        Assert.Equal(["Pagar el hosting", "Enviar la factura"], groups[1].Priorities.Select(priority => priority.Title));
        Assert.Equal(At("2026-10-12T09:20:00"), groups[0].Date);
    }

    [Fact]
    public void TheGroupsSplitAtLocalMidnight()
    {
        var groups = DoneHistory.Groups(
        [
            Done("a", "Late", "2026-10-08T23:59:59"),
            Done("b", "Early", "2026-10-09T00:00:00"),
        ]);

        Assert.Equal(["2026-10-09", "2026-10-08"], groups.Select(group => group.Day));
        Assert.Equal(["Early"], groups[0].Priorities.Select(priority => priority.Title));
        Assert.Equal(["Late"], groups[1].Priorities.Select(priority => priority.Title));
    }

    [Fact]
    public void TheGroupsCrossAMonthBoundary()
    {
        var groups = DoneHistory.Groups(
        [
            Done("a", "September", "2026-09-30T09:00:00"),
            Done("b", "October", "2026-10-01T09:00:00"),
        ]);

        Assert.Equal(["2026-10-01", "2026-09-30"], groups.Select(group => group.Day));
    }

    [Fact]
    public void NoRowsGiveNoGroups() => Assert.Empty(DoneHistory.Groups([]));

    [Fact]
    public void AnOpenPriorityIsNotInTheHistory() =>
        Assert.Empty(DoneHistory.Groups([MakePriority("open")]));

    [Fact]
    public void TheOrderInADayIsStableForTheSameSecond()
    {
        var first = Done("a", "First", "2026-10-08T09:00:00", position: 1);
        var second = Done("b", "Second", "2026-10-08T09:00:00", position: 2);

        Assert.Equal(["Second", "First"], DoneHistory.Groups([first, second])[0].Priorities.Select(priority => priority.Title));
        Assert.Equal(["Second", "First"], DoneHistory.Groups([second, first])[0].Priorities.Select(priority => priority.Title));
    }

    [Fact]
    public void ThePositionTiesBreakById()
    {
        var groups = DoneHistory.Groups(
        [
            Done("b", "B", "2026-10-08T09:00:00"),
            Done("a", "A", "2026-10-08T09:00:00"),
        ]);

        Assert.Equal(["A", "B"], groups[0].Priorities.Select(priority => priority.Title));
    }

    [Fact]
    public void TheHistoryHoldsOnlyWhatLeftTheWindow()
    {
        var recent = Done("a", "Llamar al banco", "2026-10-13T08:00:00");
        var older = Done("b", "Responder a Ana", "2026-10-12T08:45:00");
        var history = new[] { recent, older }.Where(priority => DoneWindow.IsHistory(priority.DoneAt!.Value, Now));

        Assert.Equal(["Responder a Ana"], DoneHistory.Groups(history).SelectMany(group => group.Priorities).Select(priority => priority.Title));
    }

    [Theory]
    [InlineData("2026-10-13T00:00:00", "Hoy")]
    [InlineData("2026-10-12T23:59:59", "Ayer")]
    [InlineData("2026-10-12T00:00:00", "Ayer")]
    [InlineData("2026-10-11T12:00:00", "Domingo 11 oct")]
    [InlineData("2026-10-08T12:00:00", "Jueves 8 oct")]
    [InlineData("2026-09-30T12:00:00", "Miércoles 30 sep")]
    public void TheDayTitlesUseTheSpanishLabelOfThePanel(string date, string title) =>
        Assert.Equal(title, Es.HistoryGroupTitle(At(date), At("2026-10-13T09:00:00")));

    [Fact]
    public void ADayInTheSameWeekReadsAsDayLabel() =>
        Assert.Equal("Lunes 5 oct", Es.HistoryGroupTitle(At("2026-10-05T12:00:00"), At("2026-10-12T09:00:00")));

    [Fact]
    public void YesterdayAcrossAMonthBoundaryReadsAyer() =>
        Assert.Equal("Ayer", Es.HistoryGroupTitle(At("2026-09-30T08:00:00"), At("2026-10-01T09:00:00")));

    [Fact]
    public void YesterdayAcrossAYearBoundaryReadsAyer() =>
        Assert.Equal("Ayer", Es.HistoryGroupTitle(At("2025-12-31T08:00:00"), At("2026-01-01T09:00:00")));
}
