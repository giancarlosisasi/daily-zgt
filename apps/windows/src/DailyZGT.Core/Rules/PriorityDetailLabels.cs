using DailyZGT.Core.Domain;
using DailyZGT.Core.Localization;

namespace DailyZGT.Core.Rules;

public static class DomainTitles
{
    public static string Title(this PriorityList list, Texts texts) =>
        list == PriorityList.Today ? texts.ScopeToday : texts.ScopeWeek;

    public static string Title(this RepeatRule rule, Texts texts) =>
        rule == RepeatRule.None ? texts.RepeatNo : texts.RepeatDaily;
}

public readonly record struct SubtaskProgress(int Done, int Total)
{
    public int OpenCount => Total - Done;

    // F04. The row meta, for example `1/3`.
    public string? RatioLabel(Texts texts) => Total > 0 ? texts.SubtaskRatio(Done, Total) : null;

    // F07. The line of the confirm bar.
    public string? OpenSubtasksLabel(Texts texts) => OpenCount < 1 ? null : texts.SubtasksLeft(OpenCount);

    public static SubtaskProgress Of(IEnumerable<Subtask> subtasks)
    {
        var list = subtasks.ToList();
        return new SubtaskProgress(list.Count(subtask => subtask.IsDone), list.Count);
    }
}

public static class PriorityDetailLabels
{
    // F09. `Creada hoy` or `Creada vie 9 oct · 16:00`.
    public static string Created(DateTime createdAt, DateTime now, Texts texts) =>
        createdAt.Date == now.Date ? texts.CreatedToday : texts.CreatedOn(createdAt);

    public static string Alert(DateTime? due, Texts texts) => due is null ? texts.AlertLineNoDate : texts.AlertLine;

    public static string State(Priority priority, Texts texts) => priority.IsDone ? texts.StateDone : texts.StateOpen;

    // F09. The chip `1/3 subtareas`, only when the priority has subtasks.
    public static string? Subtasks(SubtaskProgress progress, Texts texts) =>
        progress.Total > 0 ? texts.SubtasksChip(progress.Done, progress.Total) : null;
}
