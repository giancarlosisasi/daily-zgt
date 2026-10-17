using System.Globalization;
using DailyZGT.Core.Domain;

namespace DailyZGT.Core.Rules;

public static class PanelLabels
{
    // F02. `Lunes 12 oct` for Hoy, `Semana 42 · 12–18 oct` for Semana.
    public static string Date(PriorityList list, DateTime date) =>
        list == PriorityList.Today ? DayLabel(date) : WeekLabel(date);

    // F02. The scope tab, for example `Hoy · 3`.
    public static string ScopeTab(PriorityList list, int openCount) => $"{list.Title()} · {openCount}";

    // F08. The title of a history group.
    public static string HistoryDay(DateTime date, DateTime now)
    {
        if (date.Date == now.Date)
        {
            return "Hoy";
        }

        return date.Date == now.Date.AddDays(-1) ? "Ayer" : DayLabel(date);
    }

    // F19. The count of the footer. Both lists may hold every open and done priority: the rule filters by list.
    public static string Summary(
        PriorityList list,
        IEnumerable<Priority> open,
        IEnumerable<Priority> done,
        DateTime now)
    {
        var start = DoneWindow.PeriodStart(list, now);
        var doneCount = done.Count(priority => priority.List == list && priority.DoneAt >= start);
        var total = doneCount + open.Count(priority => priority.List == list);
        var suffix = list == PriorityList.Today ? "hoy" : "esta semana";
        return $"{doneCount} de {total} hechas {suffix}";
    }

    public static string Summary(PriorityList list, StoreSnapshot snapshot, DateTime now) =>
        Summary(list, snapshot.Open, snapshot.Done, now);

    private static string DayLabel(DateTime date) =>
        string.Create(
            CultureInfo.InvariantCulture,
            $"{SpanishNames.Weekday(date)} {date.Day} {SpanishNames.ShortMonth(date)}");

    private static string WeekLabel(DateTime date)
    {
        var week = ISOWeek.GetWeekOfYear(date);
        var first = LocalTime.StartOfWeek(date);
        var last = first.AddDays(6);
        var range = first.Month == last.Month
            ? $"{first.Day}–{last.Day} {SpanishNames.ShortMonth(last)}"
            : $"{first.Day} {SpanishNames.ShortMonth(first)}–{last.Day} {SpanishNames.ShortMonth(last)}";
        return string.Create(CultureInfo.InvariantCulture, $"Semana {week} · {range}");
    }
}
