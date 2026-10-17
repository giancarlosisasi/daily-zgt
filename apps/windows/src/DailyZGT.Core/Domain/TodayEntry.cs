namespace DailyZGT.Core.Domain;

// F13. A priority enters Hoy when it is created there or moved there. Restore and edits keep the old date.
public static class TodayEntry
{
    public static DateTime? EnteredAt(IEnumerable<PriorityEvent> events) =>
        events
            .Where(e => e.Type is PriorityEventType.Created or PriorityEventType.Moved)
            .MaxBy(e => (e.At, e.Id ?? 0))
            ?.At;
}
