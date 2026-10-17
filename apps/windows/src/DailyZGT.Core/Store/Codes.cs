using DailyZGT.Core.Domain;

namespace DailyZGT.Core.Store;

// The text each enum value has in the database. The macOS app writes the same strings.
internal sealed class Code<T> where T : struct, Enum
{
    private readonly Dictionary<T, string> _texts;
    private readonly Dictionary<string, T> _values;

    public Code(params (T Value, string Text)[] pairs)
    {
        _texts = pairs.ToDictionary(p => p.Value, p => p.Text);
        _values = pairs.ToDictionary(p => p.Text, p => p.Value, StringComparer.Ordinal);
    }

    public string Text(T value) => _texts[value];

    public T Parse(string text) =>
        _values.TryGetValue(text, out var value)
            ? value
            : throw new StoreException($"Unknown {typeof(T).Name} value '{text}' in the database.");
}

internal static class Codes
{
    public static readonly Code<PriorityLevel> Level = new(
        (PriorityLevel.High, "high"), (PriorityLevel.Medium, "medium"), (PriorityLevel.Low, "low"));

    public static readonly Code<PriorityList> List = new(
        (PriorityList.Today, "today"), (PriorityList.Week, "week"));

    public static readonly Code<RepeatRule> Repeat = new(
        (RepeatRule.None, "none"), (RepeatRule.Daily, "daily"));

    public static readonly Code<NoteScope> Scope = new(
        (NoteScope.Day, "day"), (NoteScope.Week, "week"));

    public static readonly Code<AlertKind> AlertKind = new(
        (Domain.AlertKind.Before30m, "before_30m"), (Domain.AlertKind.AtDue, "at_due"), (Domain.AlertKind.Snooze, "snooze"));

    public static readonly Code<AlertStatus> AlertStatus = new(
        (Domain.AlertStatus.Scheduled, "scheduled"),
        (Domain.AlertStatus.Delivered, "delivered"),
        (Domain.AlertStatus.Snoozed, "snoozed"),
        (Domain.AlertStatus.Cancelled, "cancelled"));

    public static readonly Code<PriorityEventType> Event = new(
        (PriorityEventType.Created, "created"),
        (PriorityEventType.Edited, "edited"),
        (PriorityEventType.Moved, "moved"),
        (PriorityEventType.Done, "done"),
        (PriorityEventType.Restored, "restored"),
        (PriorityEventType.SubtaskDone, "subtask_done"));
}
