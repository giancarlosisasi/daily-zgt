using System.Globalization;
using DailyZGT.Core.Localization;

namespace DailyZGT.Core.Tests.Localization;

public class DatePatternTests
{
    private static readonly DateTime Monday = new(2026, 10, 12, 12, 24, 0);
    private static readonly DateTime Friday = new(2026, 10, 9, 16, 0, 0);

    [Theory]
    [InlineData(AppLanguage.Es, "Lunes 12 oct")]
    [InlineData(AppLanguage.En, "Monday Oct 12")]
    [InlineData(AppLanguage.Pt, "Segunda 12 out")]
    public void The_day_label_follows_each_language(AppLanguage language, string expected)
    {
        Assert.Equal(expected, Texts.For(language).DayLabel(Monday));
    }

    [Theory]
    [InlineData(AppLanguage.Es, "Domingo 4 oct")]
    [InlineData(AppLanguage.En, "Sunday Oct 4")]
    [InlineData(AppLanguage.Pt, "Domingo 4 out")]
    public void The_day_label_names_a_sunday(AppLanguage language, string expected)
    {
        Assert.Equal(expected, Texts.For(language).DayLabel(new DateTime(2026, 10, 4)));
    }

    [Theory]
    [InlineData(AppLanguage.Es, "Semana 42 · 12–18 oct")]
    [InlineData(AppLanguage.En, "Week 42 · Oct 12–18")]
    [InlineData(AppLanguage.Pt, "Semana 42 · 12–18 out")]
    public void The_week_label_shows_one_month(AppLanguage language, string expected)
    {
        var texts = Texts.For(language);

        Assert.Equal(expected, texts.WeekLabel(Monday));
        Assert.Equal(expected, texts.WeekLabel(new DateTime(2026, 10, 18, 23, 59, 0)));
    }

    [Theory]
    [InlineData(AppLanguage.Es, "Semana 40 · 28 sep–4 oct")]
    [InlineData(AppLanguage.En, "Week 40 · Sep 28–Oct 4")]
    [InlineData(AppLanguage.Pt, "Semana 40 · 28 set–4 out")]
    public void The_week_label_shows_two_months(AppLanguage language, string expected)
    {
        var texts = Texts.For(language);

        Assert.Equal(expected, texts.WeekLabel(new DateTime(2026, 9, 28)));
        Assert.Equal(expected, texts.WeekLabel(new DateTime(2026, 10, 4)));
    }

    [Theory]
    [InlineData(AppLanguage.Es, "Semana 53 · 28 dic–3 ene")]
    [InlineData(AppLanguage.En, "Week 53 · Dec 28–Jan 3")]
    [InlineData(AppLanguage.Pt, "Semana 53 · 28 dez–3 jan")]
    public void The_week_label_crosses_two_years(AppLanguage language, string expected)
    {
        var texts = Texts.For(language);

        Assert.Equal(expected, texts.WeekLabel(new DateTime(2026, 12, 28)));
        Assert.Equal(expected, texts.WeekLabel(new DateTime(2027, 1, 1)));
    }

    [Theory]
    [InlineData(AppLanguage.Es, "Semana 1 · 30 dic–5 ene")]
    [InlineData(AppLanguage.En, "Week 1 · Dec 30–Jan 5")]
    [InlineData(AppLanguage.Pt, "Semana 1 · 30 dez–5 jan")]
    public void The_week_label_uses_the_iso_week_of_the_new_year(AppLanguage language, string expected)
    {
        Assert.Equal(expected, Texts.For(language).WeekLabel(new DateTime(2024, 12, 31)));
    }

    [Theory]
    [InlineData(AppLanguage.Es, "Octubre 2026")]
    [InlineData(AppLanguage.En, "October 2026")]
    [InlineData(AppLanguage.Pt, "Outubro 2026")]
    public void The_month_title_names_the_month_and_the_year(AppLanguage language, string expected)
    {
        Assert.Equal(expected, Texts.For(language).MonthTitle(Monday));
    }

    [Theory]
    [InlineData(AppLanguage.Es, "Creada vie 9 oct · 16:00")]
    [InlineData(AppLanguage.En, "Created Fri Oct 9 · 16:00")]
    [InlineData(AppLanguage.Pt, "Criada sex 9 out · 16:00")]
    public void The_created_line_names_the_day_and_the_time(AppLanguage language, string expected)
    {
        Assert.Equal(expected, Texts.For(language).CreatedOn(Friday));
    }

    [Theory]
    [InlineData(AppLanguage.Es, "Creada hoy")]
    [InlineData(AppLanguage.En, "Created today")]
    [InlineData(AppLanguage.Pt, "Criada hoje")]
    public void The_created_line_for_today(AppLanguage language, string expected)
    {
        Assert.Equal(expected, Texts.For(language).CreatedToday);
    }

    [Theory]
    [InlineData(AppLanguage.Es, "Hoy 16:00", "vie 18:00")]
    [InlineData(AppLanguage.En, "Today 16:00", "Fri 18:00")]
    [InlineData(AppLanguage.Pt, "Hoje 16:00", "sex 18:00")]
    public void The_due_chip_names_today_or_another_day(AppLanguage language, string today, string otherDay)
    {
        var texts = Texts.For(language);

        Assert.Equal(today, texts.DueToday(Friday));
        Assert.Equal(otherDay, texts.DueOtherDay(new DateTime(2026, 10, 9, 18, 0, 0)));
    }

    [Theory]
    [InlineData(AppLanguage.Es, "Vencida", "En 0 min", "En 36 min", "En 1 h 0 min", "En 1 h 20 min")]
    [InlineData(AppLanguage.En, "Overdue", "In 0 min", "In 36 min", "In 1 h 0 min", "In 1 h 20 min")]
    [InlineData(AppLanguage.Pt, "Atrasada", "Em 0 min", "Em 36 min", "Em 1 h 0 min", "Em 1 h 20 min")]
    public void The_due_chip_counts_the_time_left(
        AppLanguage language,
        string overdue,
        string zero,
        string minutes,
        string exactHour,
        string hourAndMinutes)
    {
        var texts = Texts.For(language);

        Assert.Equal(overdue, texts.DueOverdue);
        Assert.Equal(zero, texts.DueInMinutes(0));
        Assert.Equal(minutes, texts.DueInMinutes(36));
        Assert.Equal(exactHour, texts.DueInHours(1, 0));
        Assert.Equal(hourAndMinutes, texts.DueInHours(1, 20));
    }

    [Theory]
    [InlineData(AppLanguage.Es, "De ayer", "Desde vie 9")]
    [InlineData(AppLanguage.En, "From yesterday", "Since Fri 9")]
    [InlineData(AppLanguage.Pt, "De ontem", "Desde sex 9")]
    public void The_since_chip(AppLanguage language, string yesterday, string since)
    {
        var texts = Texts.For(language);

        Assert.Equal(yesterday, texts.SinceYesterday);
        Assert.Equal(since, texts.SinceDay(Friday));
    }

    [Theory]
    [InlineData(AppLanguage.Es, "Ayer", "Lunes 12 oct", "Hoy")]
    [InlineData(AppLanguage.En, "Yesterday", "Monday Oct 12", "Today")]
    [InlineData(AppLanguage.Pt, "Ontem", "Segunda 12 out", "Hoje")]
    public void The_history_group_title(AppLanguage language, string yesterday, string older, string today)
    {
        var texts = Texts.For(language);
        var now = new DateTime(2026, 10, 14, 9, 0, 0);

        Assert.Equal(yesterday, texts.HistoryGroupTitle(new DateTime(2026, 10, 13, 22, 0, 0), now));
        Assert.Equal(older, texts.HistoryGroupTitle(new DateTime(2026, 10, 12, 8, 0, 0), now));
        Assert.Equal(today, texts.HistoryGroupTitle(now, now));
    }

    [Theory]
    [InlineData(AppLanguage.Es, "Vence en 14 min", "Vence hoy 16:00", "Vence vie 18:00", "Vence en 1 h 20 min")]
    [InlineData(AppLanguage.En, "Due in 14 min", "Due today 16:00", "Due Fri 18:00", "Due in 1 h 20 min")]
    [InlineData(AppLanguage.Pt, "Vence em 14 min", "Vence hoje 16:00", "Vence sex 18:00", "Vence em 1 h 20 min")]
    public void The_alert_title_is_the_chip_text_in_lowercase(
        AppLanguage language,
        string minutes,
        string today,
        string otherDay,
        string hours)
    {
        var texts = Texts.For(language);

        Assert.Equal(minutes, texts.AlertDueTitle(texts.DueInMinutes(14)));
        Assert.Equal(today, texts.AlertDueTitle(texts.DueToday(Friday)));
        Assert.Equal(otherDay, texts.AlertDueTitle(texts.DueOtherDay(new DateTime(2026, 10, 9, 18, 0, 0))));
        Assert.Equal(hours, texts.AlertDueTitle(texts.DueInHours(1, 20)));
    }

    [Fact]
    public void The_clock_uses_two_digits_for_hours_and_minutes()
    {
        Assert.Equal("09:05", Texts.Clock(new DateTime(2026, 10, 12, 9, 5, 0)));
        Assert.Equal("00:00", Texts.Clock(new DateTime(2026, 10, 12)));
    }

    [Fact]
    public void The_patterns_ignore_the_culture_of_the_machine()
    {
        var previous = CultureInfo.CurrentCulture;
        try
        {
            CultureInfo.CurrentCulture = CultureInfo.GetCultureInfo("ar-SA");

            Assert.Equal("Monday Oct 12", Texts.En.DayLabel(Monday));
            Assert.Equal("Week 42 · Oct 12–18", Texts.En.WeekLabel(Monday));
            Assert.Equal("Lunes 12 oct", Texts.Es.DayLabel(Monday));
        }
        finally
        {
            CultureInfo.CurrentCulture = previous;
        }
    }
}
