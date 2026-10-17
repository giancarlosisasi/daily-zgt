namespace DailyZGT.Core.Domain;

public enum PriorityLevel { High, Medium, Low }

public enum PriorityList { Today, Week }

public enum RepeatRule { None, Daily }

public enum NoteScope { Day, Week }

public enum AlertKind { Before30m, AtDue, Snooze }

public enum AlertStatus { Scheduled, Delivered, Snoozed, Cancelled }

public enum PriorityEventType { Created, Edited, Moved, Done, Restored, SubtaskDone }

// The open panel tab, stored in app_state under "open_tab" as "priorities" or "notes".
public enum PanelTab { Priorities, Notes }

// Times are local wall-clock DateTime values (Kind = Local), truncated to whole seconds.
// The database stores them as "yyyy-MM-ddTHH:mm:ss" text, the same format the macOS app writes.
public sealed record Priority(
    string Id,
    string Title,
    string Note,
    PriorityLevel Level,
    PriorityList List,
    DateTime? DueAt,
    DateTime? DoneAt,
    int Position,
    DateTime CreatedAt,
    DateTime UpdatedAt,
    RepeatRule RepeatRule = RepeatRule.None,
    string? RepeatSeriesId = null)
{
    public bool IsDone => DoneAt is not null;
    public string SeriesId => RepeatSeriesId ?? Id;
}

public sealed record Subtask(
    string Id,
    string PriorityId,
    string Title,
    DateTime? DoneAt,
    int Position,
    DateTime CreatedAt)
{
    public bool IsDone => DoneAt is not null;
}

public sealed record Note(NoteScope Scope, string Period, string Body, DateTime UpdatedAt);

public sealed record PriorityAlert(
    string Id,
    string PriorityId,
    AlertKind Kind,
    DateTime FireAt,
    AlertStatus Status);

public sealed record PriorityEvent(long? Id, string PriorityId, DateTime At, PriorityEventType Type);

// One read of the whole database. Open is in list order (F03), Done is newest first.
public sealed record StoreSnapshot(
    IReadOnlyList<Priority> Open,
    IReadOnlyList<Priority> Done,
    IReadOnlyDictionary<string, IReadOnlyList<Subtask>> Subtasks,
    IReadOnlyDictionary<NoteScope, IReadOnlyDictionary<string, string>> Notes,
    IReadOnlyDictionary<string, string> AppState)
{
    public static readonly StoreSnapshot Empty = new(
        [],
        [],
        new Dictionary<string, IReadOnlyList<Subtask>>(),
        new Dictionary<NoteScope, IReadOnlyDictionary<string, string>>(),
        new Dictionary<string, string>());

    public IReadOnlyList<Subtask> SubtasksOf(string priorityId) =>
        Subtasks.TryGetValue(priorityId, out var list) ? list : [];
}
