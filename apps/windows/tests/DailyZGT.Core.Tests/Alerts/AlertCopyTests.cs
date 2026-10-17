using DailyZGT.Core.Alerts;
using DailyZGT.Core.Localization;
using static DailyZGT.Core.Tests.Rules.Languages;
using static DailyZGT.Core.Tests.Rules.RuleFixtures;

namespace DailyZGT.Core.Tests.Alerts;

public class AlertCopyTests
{
    private static readonly DateTime Due = At("2026-10-12T16:00:00");

    private static string Title(string fireAt) => AlertCopy.Title(At(fireAt), Due, Es);

    [Fact]
    public void TheAlertBeforeTheDueSaysVenceEn30Min() =>
        Assert.Equal("Vence en 30 min", Title("2026-10-12T15:30:00"));

    [Theory]
    [InlineData("2026-10-12T16:00:00")]
    [InlineData("2026-10-12T16:15:00")]
    [InlineData("2026-10-12T15:59:40")]
    public void AnAlertAtOrAfterTheDueOrLessThanHalfAMinuteBeforeSaysPrioridadVencida(string fireAt) =>
        Assert.Equal("Prioridad vencida", Title(fireAt));

    [Fact]
    public void ThirtySecondsBeforeTheDueStillSaysTheMinutesThatAreLeft() =>
        Assert.Equal("Vence en 1 min", Title("2026-10-12T15:59:30"));

    [Fact]
    public void ASnoozeBeforeTheDueSaysTheMinutesThatAreLeft()
    {
        Assert.Equal("Vence en 12 min", Title("2026-10-12T15:48:00"));
        Assert.Equal("Vence en 1 min", Title("2026-10-12T15:59:00"));
    }

    [Fact]
    public void ALongWaitUsesTheTextOfTheDueChip()
    {
        Assert.Equal("Vence en 1 h 20 min", Title("2026-10-12T14:40:00"));
        Assert.Equal("Vence hoy 16:00", Title("2026-10-12T11:00:00"));
        Assert.Equal("Vence lun 16:00", Title("2026-10-09T11:00:00"));
    }

    [Theory]
    [InlineData(AppLanguage.Es, "Vence en 30 min", "Prioridad vencida", "Vence en 1 h 20 min", "Vence hoy 16:00")]
    [InlineData(AppLanguage.En, "Due in 30 min", "Priority overdue", "Due in 1 h 20 min", "Due today 16:00")]
    [InlineData(AppLanguage.Pt, "Vence em 30 min", "Prioridade atrasada", "Vence em 1 h 20 min", "Vence hoje 16:00")]
    public void TheTitleFollowsTheLanguage(AppLanguage language, string before, string overdue, string hours, string today)
    {
        var texts = Texts.For(language);

        Assert.Equal(before, AlertCopy.Title(At("2026-10-12T15:30:00"), Due, texts));
        Assert.Equal(overdue, AlertCopy.Title(At("2026-10-12T16:00:00"), Due, texts));
        Assert.Equal(hours, AlertCopy.Title(At("2026-10-12T14:40:00"), Due, texts));
        Assert.Equal(today, AlertCopy.Title(At("2026-10-12T11:00:00"), Due, texts));
    }

    [Fact]
    public void AWeekdayChipKeepsItsCaseInEnglish() =>
        Assert.Equal("Due Fri 16:00", AlertCopy.Title(At("2026-10-08T11:00:00"), At("2026-10-09T16:00:00"), En));

    [Fact]
    public void TheRequestOfAnAlertHasTheTitleOfThePriorityAsBody()
    {
        var priority = AlertFixtures.AlertPriority(due: "2026-10-12T16:00:00", title: "Terminar el brief");
        var request = AlertRequest.From(AlertFixtures.Row("a1", Domain.AlertKind.Before30m, "2026-10-12T15:30:00"), priority, Es);

        Assert.Equal(
            new AlertRequest("a1", "Vence en 30 min", "Terminar el brief", At("2026-10-12T15:30:00"), "p1"),
            request);
    }

    [Fact]
    public void APriorityWithNoDueHasNoRequest() =>
        Assert.Null(AlertRequest.From(
            AlertFixtures.Row("a1", Domain.AlertKind.AtDue, "2026-10-12T16:00:00"),
            AlertFixtures.AlertPriority(),
            Es));

    [Fact]
    public void TheTestAlertHasItsOwnIdAndItsOwnBody() =>
        Assert.Equal(
            new AlertRequest("test-alert", "Prioridad vencida", "Revisa tu lista de hoy", Due, null),
            AlertRequest.Test(Due, Es));

    [Theory]
    [InlineData(AppLanguage.Es, "Prioridad vencida", "Revisa tu lista de hoy")]
    [InlineData(AppLanguage.En, "Priority overdue", "Check your list for today")]
    [InlineData(AppLanguage.Pt, "Prioridade atrasada", "Confira sua lista de hoje")]
    public void TheTestAlertFollowsTheLanguage(AppLanguage language, string title, string body)
    {
        var request = AlertRequest.Test(Due, Texts.For(language));

        Assert.Equal(title, request.Title);
        Assert.Equal(body, request.Body);
    }

    [Fact]
    public void TheActionLabelsMatchTheDocument()
    {
        Assert.Equal("Abrir", Es.AlertOpen);
        Assert.Equal("Posponer 15 min", Es.AlertSnooze);
        Assert.Equal("Probar alerta", Es.TestAlert);
        Assert.Equal("Las alertas están desactivadas.", Es.AlertsOff);
        Assert.Equal("Abrir ajustes", Es.OpenSettings);
    }
}
