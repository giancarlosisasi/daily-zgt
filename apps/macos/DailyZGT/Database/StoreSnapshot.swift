import GRDB

struct StoreSnapshot: Equatable, Sendable {
    var open: [Priority] = []
    var done: [Priority] = []
    var subtasks: [String: [Subtask]] = [:]
    var noteItems: [NoteItem] = []
    var appState: [String: String] = [:]

    static func fetch(_ database: Database) throws -> StoreSnapshot {
        var snapshot = StoreSnapshot()
        snapshot.open = try Priority.fetchAll(database, sql: """
            SELECT * FROM priority
            WHERE done_at IS NULL
            ORDER BY position, id
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
        snapshot.noteItems = try NoteItem.fetchAll(database, sql: """
            SELECT id, body, created_at, updated_at FROM note_item
            ORDER BY created_at DESC, id
            """)
        for entry in try AppStateEntry.fetchAll(database) {
            snapshot.appState[entry.key] = entry.value
        }
        return snapshot
    }
}
