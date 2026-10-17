using DailyZGT.Core.Domain;
using DailyZGT.Core.Localization;
using DailyZGT.Core.Rules;
using static DailyZGT.Core.Tests.Rules.Languages;
using static DailyZGT.Core.Tests.Rules.RuleFixtures;

namespace DailyZGT.Core.Tests.Rules;

public class PriorityDetailLabelsTests
{
    private static readonly DateTime Now = At("2026-10-12T10:24:00");

    [Fact]
    public void APriorityCreatedTodayShowsCreadaHoy() =>
        Assert.Equal("Creada hoy", PriorityDetailLabels.Created(At("2026-10-12T08:05:00"), Now, Es));

    [Theory]
    [InlineData("2026-10-09T17:20:00", "Creada vie 9 oct · 17:20")]
    [InlineData("2026-09-27T00:05:00", "Creada dom 27 sep · 00:05")]
    [InlineData("2026-10-11T23:59:00", "Creada dom 11 oct · 23:59")]
    public void APriorityCreatedEarlierShowsTheDayAndTheTime(string created, string label) =>
        Assert.Equal(label, PriorityDetailLabels.Created(At(created), Now, Es));

    [Fact]
    public void JustAfterMidnightIsToday() =>
        Assert.Equal("Creada hoy", PriorityDetailLabels.Created(At("2026-10-12T00:01:00"), Now, Es));

    [Fact]
    public void TheAlertTextFollowsTheDue()
    {
        Assert.Equal("30 min antes y al vencer", PriorityDetailLabels.Alert(Now, Es));
        Assert.Equal("Sin fecha, sin alerta", PriorityDetailLabels.Alert(null, Es));
    }

    [Fact]
    public void TheSubtaskChipShowsOnlyWhenTheyExist()
    {
        Assert.Equal("1/3 subtareas", PriorityDetailLabels.Subtasks(new SubtaskProgress(1, 3), Es));
        Assert.Null(PriorityDetailLabels.Subtasks(new SubtaskProgress(0, 0), Es));
    }

    [Fact]
    public void TheStateChipFollowsDone()
    {
        Assert.Equal("Pendiente", PriorityDetailLabels.State(MakePriority(), Es));
        Assert.Equal("Hecha", PriorityDetailLabels.State(MakePriority(done: "2026-10-12T10:00:00"), Es));
    }

    [Fact]
    public void TheBackLabelIsTheListName()
    {
        Assert.Equal("Hoy", PriorityList.Today.Title(Es));
        Assert.Equal("Semana", PriorityList.Week.Title(Es));
    }

    [Fact]
    public void TheRepeatKeysAreNoAndCadaDia()
    {
        Assert.Equal("No", RepeatRule.None.Title(Es));
        Assert.Equal("Cada día", RepeatRule.Daily.Title(Es));
    }

    [Theory]
    [InlineData(AppLanguage.Es, "Creada hoy", "Creada vie 9 oct · 17:20", "30 min antes y al vencer", "Pendiente", "Hecha")]
    [InlineData(AppLanguage.En, "Created today", "Created Fri Oct 9 · 17:20", "30 min before and at the due time", "Pending", "Done")]
    [InlineData(AppLanguage.Pt, "Criada hoje", "Criada sex 9 out · 17:20", "30 min antes e no prazo", "Pendente", "Concluída")]
    public void TheDetailLabelsFollowTheLanguage(
        AppLanguage language, string today, string earlier, string alert, string open, string done)
    {
        var texts = Texts.For(language);

        Assert.Equal(today, PriorityDetailLabels.Created(At("2026-10-12T08:05:00"), Now, texts));
        Assert.Equal(earlier, PriorityDetailLabels.Created(At("2026-10-09T17:20:00"), Now, texts));
        Assert.Equal(alert, PriorityDetailLabels.Alert(Now, texts));
        Assert.Equal(open, PriorityDetailLabels.State(MakePriority(), texts));
        Assert.Equal(done, PriorityDetailLabels.State(MakePriority(done: "2026-10-12T10:00:00"), texts));
    }
}

public class SubtaskProgressTests
{
    private static Subtask Subtask(string id, bool done) =>
        new(id, "p1", id, done ? At("2026-10-12T10:00:00") : null, 1, At("2026-10-12T09:00:00"));

    [Fact]
    public void TheRatioShowsDoneOverTotal() => Assert.Equal("1/3", new SubtaskProgress(1, 3).RatioLabel(Es));

    [Fact]
    public void NoSubtasksGiveNoRatio() => Assert.Null(new SubtaskProgress(0, 0).RatioLabel(Es));

    [Fact]
    public void OneOpenSubtaskReadsInTheSingular() =>
        Assert.Equal("Queda 1 subtarea abierta.", new SubtaskProgress(2, 3).OpenSubtasksLabel(Es));

    [Fact]
    public void SeveralOpenSubtasksReadInThePlural()
    {
        Assert.Equal("Quedan 2 subtareas abiertas.", new SubtaskProgress(1, 3).OpenSubtasksLabel(Es));
        Assert.Equal("Quedan 3 subtareas abiertas.", new SubtaskProgress(0, 3).OpenSubtasksLabel(Es));
    }

    [Theory]
    [InlineData(0, 0)]
    [InlineData(3, 3)]
    public void NoOpenSubtasksGiveNoLine(int done, int total) =>
        Assert.Null(new SubtaskProgress(done, total).OpenSubtasksLabel(Es));

    [Fact]
    public void ThePluralFollowsTheLanguage()
    {
        Assert.Equal("1 subtask is still open.", new SubtaskProgress(2, 3).OpenSubtasksLabel(En));
        Assert.Equal("Restam 2 subtarefas abertas.", new SubtaskProgress(1, 3).OpenSubtasksLabel(Pt));
    }

    [Fact]
    public void TheProgressCountsTheSubtasksOfAPriority()
    {
        var progress = SubtaskProgress.Of([Subtask("a", true), Subtask("b", false), Subtask("c", false)]);

        Assert.Equal(new SubtaskProgress(1, 3), progress);
        Assert.Equal(2, progress.OpenCount);
    }
}

public class TodayLimitRuleTests
{
    [Fact]
    public void TheLimitBlocksOnlyWhenOnAndFull()
    {
        Assert.True(TodayLimit.BlocksAdd(true, 5));
        Assert.True(TodayLimit.BlocksAdd(true, 6));
        Assert.False(TodayLimit.BlocksAdd(true, 4));
        Assert.False(TodayLimit.BlocksAdd(false, 5));
    }

    [Theory]
    [InlineData(AppLanguage.Es, "Hoy ya tiene 5 prioridades abiertas.")]
    [InlineData(AppLanguage.En, "Today already has 5 open priorities.")]
    public void TheLimitMessageSaysFive(AppLanguage language, string message) =>
        Assert.Equal(message, Texts.For(language).TodayLimitMessage);
}
