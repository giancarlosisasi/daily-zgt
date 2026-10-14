import GRDB

struct StoreSnapshot: Equatable, Sendable {
    var open: [Priority] = []
    var done: [Priority] = []
    var subtasks: [String: [Subtask]] = [:]
    var notes: [NoteScope: [String: String]] = [:]
    var appState: [String: String] = [:]

    static func fetch(_ database: Database) throws -> StoreSnapshot {
        var snapshot = StoreSnapshot()
        snapshot.open = try Priority.fetchAll(database, sql: """
            SELECT * FROM priority
            WHERE done_at IS NULL
            ORDER BY
                CASE level WHEN 'high' THEN 0 WHEN 'medium' THEN 1 ELSE 2 END,
                due_at IS NULL,
                due_at,
                position,
                id
            """)
        snapshot.done = try Priority.fetchAll(database, sql: """
            SELECT * FROM priority
            WHERE done_at IS NOT NULL
            ORDER BY done_at DESC, position DESC, id
            """)
        snapshot.subtasks = Dictionary(
            grouping: try Subtask.fetchAll(database, sql: "SELECT * FROM subtask ORDER BY position, id"),
            by: \.priorityID
        )
        for note in try Note.fetchAll(database) {
            snapshot.notes[note.scope, default: [:]][note.period] = note.body
        }
        for entry in try AppStateEntry.fetchAll(database) {
            snapshot.appState[entry.key] = entry.value
        }
        return snapshot
    }
}
