using DailyZGT.Core.Localization;
using DailyZGT.Core.Rules;
using static DailyZGT.Core.Tests.Rules.RuleFixtures;
using static DailyZGT.Core.Tests.Rules.Languages;

namespace DailyZGT.Core.Tests.Rules;

public class DueChipTests
{
    private static readonly DateTime Now = At("2026-10-12T10:24:00");

    private static DueChip? Chip(int minutes, int seconds = 0) =>
        DueChip.Make(Now.AddSeconds(minutes * 60 + seconds), Now, Es);

    [Fact]
    public void NoDueGivesNoChip() => Assert.Null(DueChip.Make(null, Now, Es));

    [Theory]
    [InlineData(-1)]
    [InlineData(-600)]
    public void PastDueIsOverdue(int minutes) =>
        Assert.Equal(new DueChip("Vencida", DueTone.Overdue), Chip(minutes));

    [Theory]
    [InlineData(0, "En 0 min")]
    [InlineData(1, "En 1 min")]
    [InlineData(36, "En 36 min")]
    [InlineData(59, "En 59 min")]
    [InlineData(60, "En 1 h 0 min")]
    [InlineData(80, "En 1 h 20 min")]
    [InlineData(119, "En 1 h 59 min")]
    public void LessThanTwoHoursIsSoon(int minutes, string label) =>
        Assert.Equal(new DueChip(label, DueTone.Soon), Chip(minutes));

    [Fact]
    public void TwoHoursIsNoLongerSoon() =>
        Assert.Equal(new DueChip("Hoy 12:24", DueTone.Later), Chip(120));

    [Fact]
    public void LaterTodayShowsTheTime() =>
        Assert.Equal(
            new DueChip("Hoy 16:00", DueTone.Later),
            DueChip.Make(At("2026-10-12T16:00:00"), Now, Es));

    [Theory]
    [InlineData("2026-10-16T18:00:00", "vie 18:00")]
    [InlineData("2026-10-18T09:05:00", "dom 09:05")]
    [InlineData("2026-10-14T08:00:00", "mié 08:00")]
    [InlineData("2026-10-13T23:59:00", "mar 23:59")]
    [InlineData("2026-10-22T08:00:00", "jue 08:00")]
    public void AnotherDayShowsTheWeekday(string due, string label) =>
        Assert.Equal(new DueChip(label, DueTone.Later), DueChip.Make(At(due), Now, Es));

    [Fact]
    public void TomorrowAfterMidnightIsAnotherDay() =>
        Assert.Equal(
            new DueChip("mar 00:30", DueTone.Later),
            DueChip.Make(At("2026-10-13T00:30:00"), At("2026-10-12T21:30:00"), Es));

    [Fact]
    public void HalfAMinuteRoundsToTheNearestMinute()
    {
        Assert.Equal(new DueChip("En 0 min", DueTone.Soon), Chip(0, -29));
        Assert.Equal(new DueChip("Vencida", DueTone.Overdue), Chip(0, -31));
        Assert.Equal(new DueChip("En 1 min", DueTone.Soon), Chip(0, 30));
    }

    [Fact]
    public void ThePastNeverReadsAsSoonAcrossDays() =>
        Assert.Equal(
            new DueChip("Vencida", DueTone.Overdue),
            DueChip.Make(At("2026-10-11T23:00:00"), Now, Es));
}

public class TodayEntryChipTests
{
    private static string? Label(string entered, string now) =>
        TodayEntryChip.Make(At(entered), At(now), Es)?.Label;

    [Fact]
    public void NoEntryGivesNoChip() => Assert.Null(TodayEntryChip.Make(null, At("2026-10-12T09:00:00"), Es));

    [Fact]
    public void NoChipOnTheDayOfTheEntry()
    {
        Assert.Null(Label("2026-10-12T00:00:00", "2026-10-12T09:00:00"));
        Assert.Null(Label("2026-10-12T08:59:00", "2026-10-12T23:59:59"));
    }

    [Fact]
    public void DeAyerForTheDayBefore()
    {
        Assert.Equal("De ayer", Label("2026-10-11T08:00:00", "2026-10-12T09:00:00"));
        Assert.Equal("De ayer", Label("2026-10-11T23:59:59", "2026-10-12T00:00:00"));
        Assert.Null(Label("2026-10-11T00:00:00", "2026-10-11T23:59:59"));
    }

    [Theory]
    [InlineData("2026-10-09T10:00:00", "Desde vie 9")]
    [InlineData("2026-10-10T10:00:00", "Desde sáb 10")]
    [InlineData("2026-10-04T10:00:00", "Desde dom 4")]
    [InlineData("2026-10-05T10:00:00", "Desde lun 5")]
    [InlineData("2026-10-07T10:00:00", "Desde mié 7")]
    [InlineData("2026-10-06T10:00:00", "Desde mar 6")]
    [InlineData("2026-10-08T10:00:00", "Desde jue 8")]
    public void DesdeWithTheWeekdayAndTheDayForOlderEntries(string entered, string label) =>
        Assert.Equal(label, Label(entered, "2026-10-12T09:00:00"));

    [Fact]
    public void TheMonthBoundary()
    {
        Assert.Equal("De ayer", Label("2026-09-30T10:00:00", "2026-10-01T09:00:00"));
        Assert.Equal("Desde mié 30", Label("2026-09-30T10:00:00", "2026-10-02T09:00:00"));
        Assert.Equal("Desde lun 28", Label("2026-09-28T10:00:00", "2026-10-12T09:00:00"));
    }

    [Fact]
    public void TheYearBoundary()
    {
        Assert.Equal("De ayer", Label("2025-12-31T10:00:00", "2026-01-01T09:00:00"));
        Assert.Equal("Desde mié 31", Label("2025-12-31T10:00:00", "2026-01-02T09:00:00"));
    }

    [Fact]
    public void AnEntryInTheFutureGivesNoChip() =>
        Assert.Null(Label("2026-10-13T10:00:00", "2026-10-12T09:00:00"));

    [Fact]
    public void TheChipUsesTheCalmLaterTone()
    {
        Assert.Equal(DueTone.Later, TodayEntryChip.Make(At("2026-10-09T10:00:00"), At("2026-10-12T09:00:00"), Es)!.Tone);
        Assert.Equal(DueTone.Later, TodayEntryChip.Make(At("2026-10-11T10:00:00"), At("2026-10-12T09:00:00"), Es)!.Tone);
    }
}

public class DueChipLanguageTests
{
    private static readonly DateTime Now = At("2026-10-12T10:24:00");

    public static TheoryData<AppLanguage, string, string, string, string, string> Cases => new()
    {
        { AppLanguage.Es, "Vencida", "En 36 min", "En 1 h 20 min", "Hoy 16:00", "vie 18:00" },
        { AppLanguage.En, "Overdue", "In 36 min", "In 1 h 20 min", "Today 16:00", "Fri 18:00" },
        { AppLanguage.Pt, "Atrasada", "Em 36 min", "Em 1 h 20 min", "Hoje 16:00", "sex 18:00" },
    };

    [Theory]
    [MemberData(nameof(Cases))]
    public void TheDueChipReadsInEveryLanguage(
        AppLanguage language, string overdue, string minutes, string hours, string today, string otherDay)
    {
        var texts = Texts.For(language);

        Assert.Equal(new DueChip(overdue, DueTone.Overdue), DueChip.Make(Now.AddMinutes(-5), Now, texts));
        Assert.Equal(new DueChip(minutes, DueTone.Soon), DueChip.Make(Now.AddMinutes(36), Now, texts));
        Assert.Equal(new DueChip(hours, DueTone.Soon), DueChip.Make(Now.AddMinutes(80), Now, texts));
        Assert.Equal(new DueChip(today, DueTone.Later), DueChip.Make(At("2026-10-12T16:00:00"), Now, texts));
        Assert.Equal(new DueChip(otherDay, DueTone.Later), DueChip.Make(At("2026-10-16T18:00:00"), Now, texts));
    }

    [Theory]
    [InlineData(AppLanguage.Es, "De ayer", "Desde vie 9")]
    [InlineData(AppLanguage.En, "From yesterday", "Since Fri 9")]
    [InlineData(AppLanguage.Pt, "De ontem", "Desde sex 9")]
    public void TheSinceChipReadsInEveryLanguage(AppLanguage language, string yesterday, string older)
    {
        var texts = Texts.For(language);
        var now = At("2026-10-12T09:00:00");

        Assert.Equal(yesterday, TodayEntryChip.Make(At("2026-10-11T08:00:00"), now, texts)?.Label);
        Assert.Equal(older, TodayEntryChip.Make(At("2026-10-09T10:00:00"), now, texts)?.Label);
    }
}
