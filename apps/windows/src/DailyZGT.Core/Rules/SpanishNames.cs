namespace DailyZGT.Core.Rules;

// Explicit tables: CultureInfo("es-ES") adds dots and changes with the OS. Index 0 is Sunday, as DayOfWeek.
public static class SpanishNames
{
    public static readonly IReadOnlyList<string> ShortWeekdays = ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"];

    public static readonly IReadOnlyList<string> Weekdays =
        ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"];

    public static readonly IReadOnlyList<string> ShortMonths =
        ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];

    public static string ShortWeekday(DateTime date) => ShortWeekdays[(int)date.DayOfWeek];

    public static string Weekday(DateTime date) => Weekdays[(int)date.DayOfWeek];

    public static string ShortMonth(DateTime date) => ShortMonths[date.Month - 1];

    public static string Clock(DateTime date) => $"{date.Hour:00}:{date.Minute:00}";
}
