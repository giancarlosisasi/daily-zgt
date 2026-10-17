using DailyZGT.Core.Domain;
using DailyZGT.Core.Repeat;
using Microsoft.Data.Sqlite;

namespace DailyZGT.Core.Store;

// The single writer of the database. The app calls it on the UI thread. Every write that changes a row
// reads a fresh Snapshot and raises Changed once. Writes that change nothing raise nothing.
public sealed class AppStore : IDisposable
{
    private const string PriorityColumns =
        "id, title, note, level, list, due_at, done_at, position, created_at, updated_at, repeat_rule, repeat_series_id";
    private const string SubtaskColumns = "id, priority_id, title, done_at, position, created_at";
    private const string AlertColumns = "id, priority_id, kind, fire_at, status";
    private const string EventColumns = "id, priority_id, at, type";

    private readonly SqliteConnection _connection;
    private readonly TimeProvider _clock;
    private SqliteTransaction? _transaction;
    private long _dataVersion;

    private AppStore(SqliteConnection connection, TimeProvider clock)
    {
        _connection = connection;
        _clock = clock;
        Snapshot = ReadSnapshot();
        _dataVersion = DataVersion();
    }

    public StoreSnapshot Snapshot { get; private set; }

    public event EventHandler? Changed;

    public static AppStore Open(TimeProvider clock) => OpenFile(AppDatabase.DefaultPath(), clock);

    public static AppStore OpenFile(string path, TimeProvider clock) => Opening(() => AppDatabase.OpenFile(path), clock);

    public static AppStore OpenInMemory(TimeProvider clock) => Opening(AppDatabase.OpenInMemory, clock);

    public void Dispose() => _connection.Dispose();

    public IReadOnlyList<Priority> OpenPriorities(PriorityList list) => Snapshot.Open.Where(p => p.List == list).ToList();

    public IReadOnlyList<Priority> DonePriorities(PriorityList list) => Snapshot.Done.Where(p => p.List == list).ToList();

    public int OpenCount(PriorityList list) => Snapshot.Open.Count(p => p.List == list);

    public Priority? Find(string id) => Snapshot.Open.FirstOrDefault(p => p.Id == id) ?? Snapshot.Done.FirstOrDefault(p => p.Id == id);

    public IReadOnlyList<Subtask> Subtasks(string priorityId) => Snapshot.SubtasksOf(priorityId);

    public T Value<T>(AppStateKey<T> key) => key.Decode(Snapshot.AppState.GetValueOrDefault(key.Name));

    public bool TodayLimitIsOn => Value(AppStateKeys.TodayLimit);

    public bool CanAddToToday => !TodayLimit.BlocksAdd(TodayLimitIsOn, OpenCount(PriorityList.Today));

    public string Period(NoteScope scope)
    {
        var now = LocalTime.Now(_clock);
        return scope == NoteScope.Day ? LocalTime.DayKey(now) : LocalTime.WeekKey(now);
    }

    public string NoteBody(NoteScope scope, string? period = null) =>
        Snapshot.Notes.TryGetValue(scope, out var notes) && notes.TryGetValue(period ?? Period(scope), out var body) ? body : "";

    public IReadOnlyList<Priority> DonePrioritiesAfter(PriorityList list, DateTime cutoff) => Read(() => Query(
        $"SELECT {PriorityColumns} FROM priority WHERE list = $list AND done_at IS NOT NULL AND done_at > $cutoff ORDER BY done_at DESC, position DESC, id",
        ReadPriority, ("$list", Codes.List.Text(list)), ("$cutoff", LocalTime.Text(cutoff))));

    public IReadOnlyList<Priority> DonePrioritiesAtOrBefore(PriorityList list, DateTime cutoff) => Read(() => Query(
        $"SELECT {PriorityColumns} FROM priority WHERE list = $list AND done_at IS NOT NULL AND done_at <= $cutoff ORDER BY done_at DESC, position DESC, id",
        ReadPriority, ("$list", Codes.List.Text(list)), ("$cutoff", LocalTime.Text(cutoff))));

    public int DoneCountAtOrBefore(PriorityList list, DateTime cutoff) => Read(() => Count(
        "SELECT COUNT(*) FROM priority WHERE list = $list AND done_at IS NOT NULL AND done_at <= $cutoff",
        ("$list", Codes.List.Text(list)), ("$cutoff", LocalTime.Text(cutoff))));

    public int DoneCountFrom(PriorityList list, DateTime start) => Read(() => Count(
        "SELECT COUNT(*) FROM priority WHERE list = $list AND done_at IS NOT NULL AND done_at >= $start",
        ("$list", Codes.List.Text(list)), ("$start", LocalTime.Text(start))));

    public IReadOnlyList<PriorityEvent> Events(string priorityId) => Read(() => Query(
        $"SELECT {EventColumns} FROM priority_event WHERE priority_id = $id ORDER BY id",
        ReadEvent, ("$id", priorityId)));

    // The created and moved events of the open priorities of one list, in one query (F13).
    public IReadOnlyDictionary<string, IReadOnlyList<PriorityEvent>> EnteringEvents(PriorityList list) => Read(() => Query(
            """
            SELECT e.id, e.priority_id, e.at, e.type FROM priority_event e
            JOIN priority p ON p.id = e.priority_id
            WHERE p.list = $list AND p.done_at IS NULL AND e.type IN ('created', 'moved')
            ORDER BY e.id
            """,
            ReadEvent, ("$list", Codes.List.Text(list)))
        .GroupBy(e => e.PriorityId)
        .ToDictionary(g => g.Key, g => (IReadOnlyList<PriorityEvent>)g.ToList()));

    public IReadOnlyList<PriorityAlert> Alerts(AlertStatus? status = null) => Read(() => status is { } only
        ? Query($"SELECT {AlertColumns} FROM alert WHERE status = $status ORDER BY fire_at, id", ReadAlert, ("$status", Codes.AlertStatus.Text(only)))
        : Query($"SELECT {AlertColumns} FROM alert ORDER BY fire_at, id", ReadAlert));

    public PriorityAlert? Alert(string id) => Read(() =>
        Query($"SELECT {AlertColumns} FROM alert WHERE id = $id", ReadAlert, ("$id", id)).FirstOrDefault());

    // True when another connection or process committed since the last check. Then the snapshot is fresh
    // and Changed was raised. PRAGMA data_version ignores this connection's own commits.
    public bool CheckForExternalChanges() => Guard(() =>
    {
        if (DataVersion() == _dataVersion)
        {
            return false;
        }
        Publish();
        return true;
    });

    // F05 and F17. Trims the title. In Hoy, the limit of F06 blocks the add.
    public AddOutcome AddPriority(
        string title,
        PriorityList list,
        PriorityLevel level = PriorityLevel.Medium,
        DateTime? dueAt = null,
        string note = "")
    {
        var trimmed = title.Trim();
        if (trimmed.Length == 0)
        {
            return new AddOutcome.EmptyTitle();
        }
        var at = Now();
        return Write<AddOutcome>(() =>
        {
            if (list == PriorityList.Today && TodayIsFull())
            {
                return new AddOutcome.BlockedByTodayLimit();
            }
            var priority = new Priority(
                NewId(), trimmed, note, level, list, dueAt is { } due ? LocalTime.Truncated(due) : null, null,
                NextPosition(), at, at);
            Insert(priority);
            Log(PriorityEventType.Created, priority.Id, at);
            return new AddOutcome.Added(priority);
        });
    }

    // F17. The capture window adds to Hoy with level Media and no due date.
    public AddOutcome CapturePriority(string title) => AddPriority(title, PriorityList.Today);

    // F09. A blank or unchanged title writes nothing and returns the stored priority.
    public Priority EditTitle(string id, string draft)
    {
        var trimmed = draft.Trim();
        return Edit(id, p => trimmed.Length == 0 ? p : p with { Title = trimmed });
    }

    public Priority SetLevel(string id, PriorityLevel level) => Edit(id, p => p with { Level = level });

    public Priority SetDue(string id, DateTime? dueAt) =>
        Edit(id, p => p with { DueAt = dueAt is { } due ? LocalTime.Truncated(due) : null });

    public Priority SetRepeat(string id, RepeatRule rule) => Edit(id, p => p with { RepeatRule = rule });

    // F11. A note of only whitespace is stored empty.
    public Priority SetNote(string id, string note) =>
        Edit(id, p => p with { Note = string.IsNullOrWhiteSpace(note) ? "" : note });

    // F09 and F06. A move from Semana to Hoy is blocked at the limit. A move to the same list writes nothing.
    public MoveOutcome MoveToList(string id, PriorityList list) => Write<MoveOutcome>(() =>
    {
        var current = PriorityById(id);
        if (list == PriorityList.Today && current.List == PriorityList.Week && TodayIsFull())
        {
            return new MoveOutcome.BlockedByTodayLimit();
        }
        return new MoveOutcome.Moved(EditInTransaction(current, current with { List = list }));
    });

    public Priority MarkDone(string id)
    {
        var at = Now();
        return Write(() =>
        {
            var priority = PriorityById(id);
            if (priority.IsDone)
            {
                return priority;
            }
            priority = priority with { DoneAt = at, UpdatedAt = at };
            Update(priority);
            Log(PriorityEventType.Done, id, at);
            return priority;
        });
    }

    // F07, F08, F14. An open copy of the same series that the person never changed gives its place back.
    // A changed copy stays, and the restored priority leaves the series.
    public Priority Restore(string id)
    {
        var at = Now();
        return Write(() =>
        {
            var priority = PriorityById(id);
            if (!priority.IsDone)
            {
                return priority;
            }
            var openCopies = Query(
                $"SELECT {PriorityColumns} FROM priority WHERE COALESCE(repeat_series_id, id) = $series AND done_at IS NULL ORDER BY position, id",
                ReadPriority, ("$series", priority.SeriesId));
            if (openCopies.Any(PersonChanged))
            {
                priority = priority with { RepeatRule = RepeatRule.None, RepeatSeriesId = NewId() };
            }
            else
            {
                foreach (var copy in openCopies)
                {
                    Execute("DELETE FROM priority WHERE id = $id", ("$id", copy.Id));
                }
            }
            priority = priority with { DoneAt = null, UpdatedAt = at };
            Update(priority);
            Log(PriorityEventType.Restored, id, at);
            return priority;
        });
    }

    // F14. Deleting an open priority ends its series. Deleting a done one does not.
    public Priority Delete(string id)
    {
        var at = Now();
        return Write(() =>
        {
            var priority = PriorityById(id);
            Execute("DELETE FROM priority WHERE id = $id", ("$id", id));
            if (!priority.IsDone)
            {
                EndSeries(priority.SeriesId, at);
            }
            return priority;
        });
    }

    // F14. Adds the open copy of every series that is ready. The limit of F06 never blocks it.
    public IReadOnlyList<Priority> AddRepeatCopies()
    {
        var at = Now();
        return Write<IReadOnlyList<Priority>>(() =>
        {
            var priorities = Query($"SELECT {PriorityColumns} FROM priority", ReadPriority);
            var subtasks = Query($"SELECT {SubtaskColumns} FROM subtask", ReadSubtask)
                .GroupBy(s => s.PriorityId)
                .ToDictionary(g => g.Key, g => (IReadOnlyList<Subtask>)g.ToList());
            var position = priorities.Select(p => p.Position).DefaultIfEmpty(0).Max();
            var added = new List<Priority>();
            foreach (var copy in RepeatPlanner.Copies(priorities, subtasks, at, _clock.LocalTimeZone))
            {
                var priority = new Priority(
                    NewId(), copy.Title, copy.Note, copy.Level, PriorityList.Today, copy.DueAt, null,
                    ++position, at, at, RepeatRule.Daily, copy.SeriesId);
                Insert(priority);
                for (var index = 0; index < copy.SubtaskTitles.Count; index++)
                {
                    Insert(new Subtask(NewId(), priority.Id, copy.SubtaskTitles[index], null, index + 1, at));
                }
                Log(PriorityEventType.Created, priority.Id, at);
                added.Add(priority);
            }
            return added;
        });
    }

    // Trims the title. A blank title adds nothing and returns null.
    public Subtask? AddSubtask(string priorityId, string title)
    {
        var trimmed = title.Trim();
        if (trimmed.Length == 0)
        {
            return null;
        }
        var at = Now();
        return Write(() =>
        {
            PriorityById(priorityId);
            var position = Count("SELECT COALESCE(MAX(position), 0) FROM subtask WHERE priority_id = $id", ("$id", priorityId)) + 1;
            var subtask = new Subtask(NewId(), priorityId, trimmed, null, position, at);
            Insert(subtask);
            Log(PriorityEventType.Edited, priorityId, at);
            return subtask;
        });
    }

    public Subtask ToggleSubtask(string id)
    {
        var at = Now();
        return Write(() =>
        {
            var subtask = Query($"SELECT {SubtaskColumns} FROM subtask WHERE id = $id", ReadSubtask, ("$id", id)).FirstOrDefault()
                ?? throw new StoreException($"Subtask {id} is not in the database.");
            subtask = subtask with { DoneAt = subtask.IsDone ? null : at };
            Execute("UPDATE subtask SET done_at = $done WHERE id = $id", ("$done", TextOrNull(subtask.DoneAt)), ("$id", id));
            Log(subtask.IsDone ? PriorityEventType.SubtaskDone : PriorityEventType.Edited, subtask.PriorityId, at);
            return subtask;
        });
    }

    // A body equal to the stored one writes nothing, so clearing a note that was never saved saves nothing.
    public void SaveNote(NoteScope scope, string body, string? period = null)
    {
        var at = Now();
        var key = period ?? Period(scope);
        Write(() =>
        {
            var stored = Query(
                "SELECT body FROM note WHERE scope = $scope AND period = $period",
                r => r.GetString(0), ("$scope", Codes.Scope.Text(scope)), ("$period", key)).FirstOrDefault() ?? "";
            if (stored == body)
            {
                return 0;
            }
            return Execute(
                """
                INSERT INTO note (scope, period, body, updated_at) VALUES ($scope, $period, $body, $at)
                ON CONFLICT (scope, period) DO UPDATE SET body = excluded.body, updated_at = excluded.updated_at
                """,
                ("$scope", Codes.Scope.Text(scope)), ("$period", key), ("$body", body), ("$at", LocalTime.Text(at)));
        });
    }

    public void SetValue<T>(AppStateKey<T> key, T value) => Write(() => Execute(
        "INSERT INTO app_state (key, value) VALUES ($key, $value) ON CONFLICT (key) DO UPDATE SET value = excluded.value",
        ("$key", key.Name), ("$value", key.Encode(value))));

    // Inserts or updates each row by id. A row of a priority that is gone is skipped.
    public void SaveAlerts(IEnumerable<PriorityAlert> alerts)
    {
        var rows = alerts.ToList();
        if (rows.Count == 0)
        {
            return;
        }
        Write(() =>
        {
            foreach (var alert in rows)
            {
                Execute(
                    """
                    INSERT INTO alert (id, priority_id, kind, fire_at, status)
                    SELECT $id, $priority, $kind, $fireAt, $status WHERE EXISTS (SELECT 1 FROM priority WHERE id = $priority)
                    ON CONFLICT (id) DO UPDATE SET fire_at = excluded.fire_at, status = excluded.status
                    """,
                    ("$id", alert.Id),
                    ("$priority", alert.PriorityId),
                    ("$kind", Codes.AlertKind.Text(alert.Kind)),
                    ("$fireAt", LocalTime.Text(alert.FireAt)),
                    ("$status", Codes.AlertStatus.Text(alert.Status)));
            }
            return 0;
        });
    }

    private Priority Edit(string id, Func<Priority, Priority> change) =>
        Write(() =>
        {
            var current = PriorityById(id);
            return EditInTransaction(current, change(current));
        });

    // Writes "moved" when the list changed and "edited" when anything else changed.
    private Priority EditInTransaction(Priority current, Priority edited)
    {
        var moved = edited.List != current.List;
        var changed = edited with { List = current.List } != current;
        if (!moved && !changed)
        {
            return current;
        }
        var at = Now();
        edited = edited with { UpdatedAt = at };
        Update(edited);
        if (moved)
        {
            Log(PriorityEventType.Moved, current.Id, at);
        }
        if (changed)
        {
            Log(PriorityEventType.Edited, current.Id, at);
        }
        return edited;
    }

    private void EndSeries(string seriesId, DateTime at)
    {
        var ids = Query(
            "SELECT id FROM priority WHERE COALESCE(repeat_series_id, id) = $series AND repeat_rule <> 'none' ORDER BY position, id",
            r => r.GetString(0), ("$series", seriesId));
        foreach (var id in ids)
        {
            Execute("UPDATE priority SET repeat_rule = 'none' WHERE id = $id", ("$id", id));
            Log(PriorityEventType.Edited, id, at);
        }
    }

    // A copy the person changed has an event other than "created": an edit, a move or a subtask.
    private bool PersonChanged(Priority copy) =>
        Count("SELECT EXISTS (SELECT 1 FROM priority_event WHERE priority_id = $id AND type <> 'created')", ("$id", copy.Id)) == 1;

    private bool TodayIsFull()
    {
        var isOn = AppStateKeys.TodayLimit.Decode(
            Query("SELECT value FROM app_state WHERE key = $key", r => r.GetString(0), ("$key", AppStateKeys.TodayLimit.Name)).FirstOrDefault());
        var openToday = Count("SELECT COUNT(*) FROM priority WHERE list = 'today' AND done_at IS NULL");
        return TodayLimit.BlocksAdd(isOn, openToday);
    }

    private int NextPosition() => Count("SELECT COALESCE(MAX(position), 0) FROM priority") + 1;

    private void Log(PriorityEventType type, string priorityId, DateTime at)
    {
        Execute(
            "INSERT INTO priority_event (priority_id, at, type) VALUES ($id, $at, $type)",
            ("$id", priorityId), ("$at", LocalTime.Text(at)), ("$type", Codes.Event.Text(type)));
        Execute("UPDATE priority SET updated_at = $at WHERE id = $id", ("$at", LocalTime.Text(at)), ("$id", priorityId));
    }

    private Priority PriorityById(string id) =>
        Query($"SELECT {PriorityColumns} FROM priority WHERE id = $id", ReadPriority, ("$id", id)).FirstOrDefault()
        ?? throw new StoreException($"Priority {id} is not in the database.");

    private void Insert(Priority p) => Execute(
        $"""
        INSERT INTO priority ({PriorityColumns})
        VALUES ($id, $title, $note, $level, $list, $due, $done, $position, $created, $updated, $rule, $series)
        """,
        PriorityArguments(p));

    private void Update(Priority p) => Execute(
        """
        UPDATE priority SET title = $title, note = $note, level = $level, list = $list, due_at = $due, done_at = $done,
            position = $position, created_at = $created, updated_at = $updated, repeat_rule = $rule, repeat_series_id = $series
        WHERE id = $id
        """,
        PriorityArguments(p));

    private static (string, object?)[] PriorityArguments(Priority p) =>
    [
        ("$id", p.Id), ("$title", p.Title), ("$note", p.Note), ("$level", Codes.Level.Text(p.Level)),
        ("$list", Codes.List.Text(p.List)), ("$due", TextOrNull(p.DueAt)), ("$done", TextOrNull(p.DoneAt)),
        ("$position", p.Position), ("$created", LocalTime.Text(p.CreatedAt)), ("$updated", LocalTime.Text(p.UpdatedAt)),
        ("$rule", Codes.Repeat.Text(p.RepeatRule)), ("$series", p.RepeatSeriesId),
    ];

    private void Insert(Subtask s) => Execute(
        $"INSERT INTO subtask ({SubtaskColumns}) VALUES ($id, $priority, $title, $done, $position, $created)",
        ("$id", s.Id), ("$priority", s.PriorityId), ("$title", s.Title), ("$done", TextOrNull(s.DoneAt)),
        ("$position", s.Position), ("$created", LocalTime.Text(s.CreatedAt)));

    private StoreSnapshot ReadSnapshot() => Read(() =>
    {
        var open = Query(
            $"""
            SELECT {PriorityColumns} FROM priority
            WHERE done_at IS NULL
            ORDER BY
                CASE level WHEN 'high' THEN 0 WHEN 'medium' THEN 1 ELSE 2 END,
                due_at IS NULL,
                due_at,
                position,
                id
            """,
            ReadPriority);
        var done = Query(
            $"SELECT {PriorityColumns} FROM priority WHERE done_at IS NOT NULL ORDER BY done_at DESC, position DESC, id",
            ReadPriority);
        var subtasks = Query($"SELECT {SubtaskColumns} FROM subtask ORDER BY position, id", ReadSubtask)
            .GroupBy(s => s.PriorityId)
            .ToDictionary(g => g.Key, g => (IReadOnlyList<Subtask>)g.ToList());
        var notes = Query("SELECT scope, period, body FROM note", r => (Scope: Codes.Scope.Parse(r.GetString(0)), Period: r.GetString(1), Body: r.GetString(2)))
            .GroupBy(n => n.Scope)
            .ToDictionary(g => g.Key, g => (IReadOnlyDictionary<string, string>)g.ToDictionary(n => n.Period, n => n.Body));
        var appState = Query("SELECT key, value FROM app_state", r => (Key: r.GetString(0), Value: r.GetString(1)))
            .ToDictionary(e => e.Key, e => e.Value);
        return new StoreSnapshot(open, done, subtasks, notes, appState);
    });

    private void Publish()
    {
        Snapshot = ReadSnapshot();
        _dataVersion = DataVersion();
        Changed?.Invoke(this, EventArgs.Empty);
    }

    private static Priority ReadPriority(SqliteDataReader r) => new(
        r.GetString(0),
        r.GetString(1),
        r.GetString(2),
        Codes.Level.Parse(r.GetString(3)),
        Codes.List.Parse(r.GetString(4)),
        OptionalTime(r, 5),
        OptionalTime(r, 6),
        r.GetInt32(7),
        RequiredTime(r, 8),
        RequiredTime(r, 9),
        Codes.Repeat.Parse(r.GetString(10)),
        r.IsDBNull(11) ? null : r.GetString(11));

    private static Subtask ReadSubtask(SqliteDataReader r) =>
        new(r.GetString(0), r.GetString(1), r.GetString(2), OptionalTime(r, 3), r.GetInt32(4), RequiredTime(r, 5));

    private static PriorityAlert ReadAlert(SqliteDataReader r) => new(
        r.GetString(0), r.GetString(1), Codes.AlertKind.Parse(r.GetString(2)), RequiredTime(r, 3), Codes.AlertStatus.Parse(r.GetString(4)));

    private static PriorityEvent ReadEvent(SqliteDataReader r) =>
        new(r.GetInt64(0), r.GetString(1), RequiredTime(r, 2), Codes.Event.Parse(r.GetString(3)));

    private static DateTime RequiredTime(SqliteDataReader r, int column) =>
        LocalTime.Parse(r.GetString(column)) ?? throw new StoreException($"Unreadable time '{r.GetString(column)}' in the database.");

    private static DateTime? OptionalTime(SqliteDataReader r, int column) => r.IsDBNull(column) ? null : RequiredTime(r, column);

    private static string? TextOrNull(DateTime? time) => time is { } value ? LocalTime.Text(value) : null;

    private DateTime Now() => LocalTime.Now(_clock);

    private static string NewId() => Guid.NewGuid().ToString().ToUpperInvariant();

    private long DataVersion() => Long("PRAGMA data_version");

    // One IMMEDIATE transaction. Changed is raised only when the transaction changed a row.
    private T Write<T>(Func<T> work) => Guard(() =>
    {
        var before = Long("SELECT total_changes()");
        T result;
        using (var transaction = _connection.BeginTransaction(deferred: false))
        {
            _transaction = transaction;
            try
            {
                result = work();
                transaction.Commit();
            }
            finally
            {
                _transaction = null;
            }
        }
        if (Long("SELECT total_changes()") != before)
        {
            Publish();
        }
        return result;
    });

    private T Read<T>(Func<T> work) => Guard(() =>
    {
        if (_transaction is not null)
        {
            return work();
        }
        using var transaction = _connection.BeginTransaction(deferred: true);
        _transaction = transaction;
        try
        {
            return work();
        }
        finally
        {
            _transaction = null;
        }
    });

    private static T Guard<T>(Func<T> work)
    {
        try
        {
            return work();
        }
        catch (SqliteException error)
        {
            throw new StoreException(error.Message, error);
        }
    }

    private static AppStore Opening(Func<SqliteConnection> connect, TimeProvider clock)
    {
        SqliteConnection? connection = null;
        try
        {
            connection = connect();
            return new AppStore(connection, clock);
        }
        catch (Exception error) when (error is SqliteException or IOException or UnauthorizedAccessException or StoreException)
        {
            connection?.Dispose();
            throw error as StoreException ?? new StoreException(error.Message, error);
        }
    }

    private SqliteCommand Command(string sql, (string Name, object? Value)[] arguments)
    {
        var command = _connection.CreateCommand();
        command.Transaction = _transaction;
        command.CommandText = sql;
        foreach (var (name, value) in arguments)
        {
            command.Parameters.AddWithValue(name, value ?? DBNull.Value);
        }
        return command;
    }

    private int Execute(string sql, params (string Name, object? Value)[] arguments)
    {
        using var command = Command(sql, arguments);
        return command.ExecuteNonQuery();
    }

    private int Count(string sql, params (string Name, object? Value)[] arguments) => checked((int)Long(sql, arguments));

    private long Long(string sql, params (string Name, object? Value)[] arguments)
    {
        using var command = Command(sql, arguments);
        return Convert.ToInt64(command.ExecuteScalar());
    }

    private List<T> Query<T>(string sql, Func<SqliteDataReader, T> read, params (string Name, object? Value)[] arguments)
    {
        using var command = Command(sql, arguments);
        using var reader = command.ExecuteReader();
        var rows = new List<T>();
        while (reader.Read())
        {
            rows.Add(read(reader));
        }
        return rows;
    }
}
