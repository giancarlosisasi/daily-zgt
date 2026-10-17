using DailyZGT.Core.Domain;
using DailyZGT.Core.Rules;
using static DailyZGT.Core.Tests.Rules.RuleFixtures;

namespace DailyZGT.Core.Tests.Rules;

public class PriorityDetailLabelsTests
{
    private static readonly DateTime Now = At("2026-10-12T10:24:00");

    [Fact]
    public void APriorityCreatedTodayShowsCreadaHoy() =>
        Assert.Equal("Creada hoy", PriorityDetailLabels.Created(At("2026-10-12T08:05:00"), Now));

    [Theory]
    [InlineData("2026-10-09T17:20:00", "Creada vie 9 oct · 17:20")]
    [InlineData("2026-09-27T00:05:00", "Creada dom 27 sep · 00:05")]
    [InlineData("2026-10-11T23:59:00", "Creada dom 11 oct · 23:59")]
    public void APriorityCreatedEarlierShowsTheDayAndTheTime(string created, string label) =>
        Assert.Equal(label, PriorityDetailLabels.Created(At(created), Now));

    [Fact]
    public void JustAfterMidnightIsToday() =>
        Assert.Equal("Creada hoy", PriorityDetailLabels.Created(At("2026-10-12T00:01:00"), Now));

    [Fact]
    public void TheAlertTextFollowsTheDue()
    {
        Assert.Equal("30 min antes y al vencer", PriorityDetailLabels.Alert(Now));
        Assert.Equal("Sin fecha, sin alerta", PriorityDetailLabels.Alert(null));
    }

    [Fact]
    public void TheSubtaskChipShowsOnlyWhenTheyExist()
    {
        Assert.Equal("1/3 subtareas", PriorityDetailLabels.Subtasks(new SubtaskProgress(1, 3)));
        Assert.Null(PriorityDetailLabels.Subtasks(new SubtaskProgress(0, 0)));
    }

    [Fact]
    public void TheStateChipFollowsDone()
    {
        Assert.Equal("Pendiente", PriorityDetailLabels.State(MakePriority()));
        Assert.Equal("Hecha", PriorityDetailLabels.State(MakePriority(done: "2026-10-12T10:00:00")));
    }

    [Fact]
    public void TheBackLabelIsTheListName()
    {
        Assert.Equal("Hoy", PriorityList.Today.Title());
        Assert.Equal("Semana", PriorityList.Week.Title());
    }

    [Fact]
    public void TheRepeatKeysAreNoAndCadaDia()
    {
        Assert.Equal("No", RepeatRule.None.Title());
        Assert.Equal("Cada día", RepeatRule.Daily.Title());
    }
}

public class SubtaskProgressTests
{
    private static Subtask Subtask(string id, bool done) =>
        new(id, "p1", id, done ? At("2026-10-12T10:00:00") : null, 1, At("2026-10-12T09:00:00"));

    [Fact]
    public void TheRatioShowsDoneOverTotal() => Assert.Equal("1/3", new SubtaskProgress(1, 3).RatioLabel);

    [Fact]
    public void NoSubtasksGiveNoRatio() => Assert.Null(new SubtaskProgress(0, 0).RatioLabel);

    [Fact]
    public void OneOpenSubtaskReadsInTheSingular() =>
        Assert.Equal("Queda 1 subtarea abierta.", new SubtaskProgress(2, 3).OpenSubtasksLabel);

    [Fact]
    public void SeveralOpenSubtasksReadInThePlural()
    {
        Assert.Equal("Quedan 2 subtareas abiertas.", new SubtaskProgress(1, 3).OpenSubtasksLabel);
        Assert.Equal("Quedan 3 subtareas abiertas.", new SubtaskProgress(0, 3).OpenSubtasksLabel);
    }

    [Theory]
    [InlineData(0, 0)]
    [InlineData(3, 3)]
    public void NoOpenSubtasksGiveNoLine(int done, int total) =>
        Assert.Null(new SubtaskProgress(done, total).OpenSubtasksLabel);

    [Fact]
    public void TheProgressCountsTheSubtasksOfAPriority()
    {
        var progress = SubtaskProgress.Of([Subtask("a", true), Subtask("b", false), Subtask("c", false)]);

        Assert.Equal(new SubtaskProgress(1, 3), progress);
        Assert.Equal(2, progress.OpenCount);
    }
}

public class PanelCopyTests
{
    [Fact]
    public void TheLimitBlocksOnlyWhenOnAndFull()
    {
        Assert.True(TodayLimit.BlocksAdd(true, 5));
        Assert.True(TodayLimit.BlocksAdd(true, 6));
        Assert.False(TodayLimit.BlocksAdd(true, 4));
        Assert.False(TodayLimit.BlocksAdd(false, 5));
    }

    [Fact]
    public void TheLimitMessageSaysFive() =>
        Assert.Equal("Hoy ya tiene 5 prioridades abiertas.", TodayLimit.Message);

    [Fact]
    public void TheDoneHeaderShowsTheCount()
    {
        Assert.Equal("Hechas (1)", PriorityListCopy.DoneHeader(1));
        Assert.Equal("Hechas (0)", PriorityListCopy.DoneHeader(0));
    }

    [Fact]
    public void TheUndoLineNamesThePriority() =>
        Assert.Equal("Hecha: Terminar el brief", PriorityListCopy.UndoLine("Terminar el brief"));
}
