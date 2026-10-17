using System.Globalization;

namespace DailyZGT.Core.Domain;

public static class LocalTime
{
    private const string TimestampFormat = "yyyy-MM-dd'T'HH:mm:ss";

    public static string Text(DateTime local) =>
        local.ToString(TimestampFormat, CultureInfo.InvariantCulture);

    public static DateTime? Parse(string? text) =>
        DateTime.TryParseExact(text, TimestampFormat, CultureInfo.InvariantCulture, DateTimeStyles.AssumeLocal, out var value)
            ? DateTime.SpecifyKind(value, DateTimeKind.Local)
            : null;

    public static DateTime Truncated(DateTime local) =>
        new(local.Ticks - local.Ticks % TimeSpan.TicksPerSecond, DateTimeKind.Local);

    public static DateTime Now(TimeProvider clock) =>
        Truncated(clock.GetLocalNow().DateTime);

    public static string DayKey(DateTime local) =>
        local.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

    public static string WeekKey(DateTime local) =>
        string.Format(CultureInfo.InvariantCulture, "{0:0000}-W{1:00}", ISOWeek.GetYear(local), ISOWeek.GetWeekOfYear(local));

    public static DateTime StartOfDay(DateTime local) =>
        DateTime.SpecifyKind(local.Date, DateTimeKind.Local);

    public static DateTime StartOfWeek(DateTime local)
    {
        var day = StartOfDay(local);
        var sinceMonday = ((int)day.DayOfWeek + 6) % 7;
        return day.AddDays(-sinceMonday);
    }
}
