using DailyZGT.Core.Domain;

namespace DailyZGT.Core.Rules;

public static class DomainTitles
{
    public static string Title(this PriorityList list) => list == PriorityList.Today ? "Hoy" : "Semana";

    public static string Title(this RepeatRule rule) => rule == RepeatRule.None ? "No" : "Cada día";
}

public readonly record struct SubtaskProgress(int Done, int Total)
{
    public int OpenCount => Total - Done;

    // F04. The row meta, for example `1/3`.
    public string? RatioLabel => Total > 0 ? $"{Done}/{Total}" : null;

    // F07. The line of the confirm bar.
    public string? OpenSubtasksLabel => OpenCount switch
    {
        < 1 => null,
        1 => "Queda 1 subtarea abierta.",
        _ => $"Quedan {OpenCount} subtareas abiertas.",
    };

    public static SubtaskProgress Of(IEnumerable<Subtask> subtasks)
    {
        var list = subtasks.ToList();
        return new SubtaskProgress(list.Count(subtask => subtask.IsDone), list.Count);
    }
}

public static class PriorityDetailLabels
{
    // F09. `Creada hoy` or `Creada vie 9 oct · 16:00`.
    public static string Created(DateTime createdAt, DateTime now) =>
        createdAt.Date == now.Date
            ? "Creada hoy"
            : $"Creada {SpanishNames.ShortWeekday(createdAt)} {createdAt.Day} {SpanishNames.ShortMonth(createdAt)} · {SpanishNames.Clock(createdAt)}";

    public static string Alert(DateTime? due) => due is null ? "Sin fecha, sin alerta" : "30 min antes y al vencer";

    public static string State(Priority priority) => priority.IsDone ? "Hecha" : "Pendiente";

    // F09. The chip `1/3 subtareas`, only when the priority has subtasks.
    public static string? Subtasks(SubtaskProgress progress) =>
        progress.Total > 0 ? $"{progress.Done}/{progress.Total} subtareas" : null;
}
