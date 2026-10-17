using DailyZGT.Core.Domain;
using DailyZGT.Core.Localization;

namespace DailyZGT.Core.Rules;

public static class PanelLabels
{
    // F02. `Lunes 12 oct` for Hoy, `Semana 42 · 12–18 oct` for Semana.
    public static string Date(PriorityList list, DateTime date, Texts texts) =>
        list == PriorityList.Today ? texts.DayLabel(date) : texts.WeekLabel(date);

    // F02. The scope tab, for example `Hoy · 3`.
    public static string ScopeTab(PriorityList list, int openCount, Texts texts) =>
        list == PriorityList.Today ? texts.TodayTab(openCount) : texts.WeekTab(openCount);

    // F19. The count of the footer. Both lists may hold every open and done priority: the rule filters by list.
    public static string Summary(
        PriorityList list,
        IEnumerable<Priority> open,
        IEnumerable<Priority> done,
        DateTime now,
        Texts texts)
    {
        var start = DoneWindow.PeriodStart(list, now);
        var doneCount = done.Count(priority => priority.List == list && priority.DoneAt >= start);
        var total = doneCount + open.Count(priority => priority.List == list);
        return list == PriorityList.Today ? texts.FooterToday(doneCount, total) : texts.FooterWeek(doneCount, total);
    }

    public static string Summary(PriorityList list, StoreSnapshot snapshot, DateTime now, Texts texts) =>
        Summary(list, snapshot.Open, snapshot.Done, now, texts);
}
