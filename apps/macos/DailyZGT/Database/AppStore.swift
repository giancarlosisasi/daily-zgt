import Foundation
import GRDB
import Observation

struct SubtaskProgress: Equatable, Sendable {
    var done: Int
    var total: Int
}

struct AppStateKey<Value: Codable & Sendable>: Sendable {
    let name: String
    let defaultValue: Value
}

enum AppStoreError: Error, Equatable {
    case priorityNotFound(String)
    case subtaskNotFound(String)
    case noteNotFound(String)
}

@Observable
@MainActor
final class AppStore {
    private(set) var snapshot = StoreSnapshot()
    private(set) var observationError: (any Error)?

    let database: DatabaseQueue
    let images: NoteImageStore
    let now: @MainActor () -> Date

    @ObservationIgnored private var observation: AnyDatabaseCancellable?
    @ObservationIgnored private var watcher: ExternalChangeWatcher?

    init(database: DatabaseQueue, now: @escaping @MainActor () -> Date = { Date() }) {
        self.database = database
        images = NoteImageStore(database: database)
        self.now = now
        watcher = ExternalChangeWatcher(database: database)
        observation = ValueObservation
            .tracking { try StoreSnapshot.fetch($0) }
            .start(
                in: database,
                scheduling: .immediate,
                onError: { [weak self] error in self?.observationError = error },
                onChange: { [weak self] snapshot in self?.apply(snapshot) }
            )
    }

    var dueDays: DueDays {
        DueDays(now: now())
    }

    func openGroups(in filter: DueFilter, days: DueDays? = nil) -> [DueGroup] {
        filter.groups(snapshot.open, days ?? dueDays)
    }

    func openPriorities(in filter: DueFilter, days: DueDays? = nil) -> [Priority] {
        filter.open(snapshot.open, days ?? dueDays)
    }

    func openCount(in filter: DueFilter, days: DueDays? = nil) -> Int {
        filter.counted(snapshot.open, days ?? dueDays).count
    }

    func hiddenOverdueCount(in filter: DueFilter, days: DueDays? = nil) -> Int {
        filter.hiddenOverdueCount(snapshot.open, days ?? dueDays)
    }

    func donePriorities(in filter: DueFilter, days: DueDays? = nil) -> [Priority] {
        let days = days ?? dueDays
        return snapshot.done.filter { filter.showsDone($0, days) }
    }

    func olderDonePriorities(outside filter: DueFilter, days: DueDays? = nil) -> [Priority] {
        let days = days ?? dueDays
        return snapshot.done.filter { !filter.showsDone($0, days) }
    }

    func priority(id: Priority.ID) -> Priority? {
        snapshot.open.first { $0.id == id } ?? snapshot.done.first { $0.id == id }
    }

    func subtasks(of priorityID: Priority.ID) -> [Subtask] {
        snapshot.subtasks[priorityID] ?? []
    }

    func subtaskProgress(of priorityID: Priority.ID) -> SubtaskProgress {
        let subtasks = subtasks(of: priorityID)
        return SubtaskProgress(done: subtasks.filter(\.isDone).count, total: subtasks.count)
    }

    func events(of priorityID: Priority.ID) throws -> [PriorityEvent] {
        try database.read { database in
            try PriorityEvent.fetchAll(
                database,
                sql: "SELECT * FROM priority_event WHERE priority_id = ? ORDER BY id",
                arguments: [priorityID]
            )
        }
    }

    func alerts(status: AlertStatus? = nil) throws -> [PriorityAlert] {
        try database.read { database in
            guard let status else {
                return try PriorityAlert.fetchAll(database, sql: "SELECT * FROM alert ORDER BY fire_at, id")
            }
            return try PriorityAlert.fetchAll(
                database,
                sql: "SELECT * FROM alert WHERE status = ? ORDER BY fire_at, id",
                arguments: [status]
            )
        }
    }

    func alert(id: PriorityAlert.ID) throws -> PriorityAlert? {
        try database.read { try PriorityAlert.fetchOne($0, key: id) }
    }

    func note(id: NoteItem.ID) -> NoteItem? {
        snapshot.noteItems.first { $0.id == id }
    }

    func notes(in filter: DueFilter, days: DueDays? = nil) -> [NoteItem] {
        let days = days ?? dueDays
        return snapshot.noteItems.filter { filter.includesNote($0, days) }
    }

    func value<Value>(for key: AppStateKey<Value>) -> Value {
        guard let text = snapshot.appState[key.name],
              let value = try? JSONDecoder().decode(Value.self, from: Data(text.utf8))
        else {
            return key.defaultValue
        }
        return value
    }

    @discardableResult
    func addPriority(
        title: String,
        level: PriorityLevel = .medium,
        list: PriorityList = .today,
        dueAt: Date? = nil,
        note: String = ""
    ) throws -> Priority {
        let at = timestamp()
        return try write { database in
            let lastPosition = try Int.fetchOne(database, sql: "SELECT MAX(position) FROM priority") ?? 0
            let priority = Priority(
                id: UUID().uuidString,
                title: title,
                note: note,
                level: level,
                list: list,
                dueAt: dueAt.map(LocalTime.truncated),
                doneAt: nil,
                position: lastPosition + 1,
                createdAt: at,
                updatedAt: at
            )
            try priority.insert(database)
            try Self.log(.created, on: priority.id, at: at, in: database)
            return priority
        }
    }

    @discardableResult
    func editPriority(
        _ id: Priority.ID,
        _ change: @Sendable (inout Priority) -> Void
    ) throws -> Priority {
        let at = timestamp()
        return try write { database in
            let current = try Self.priority(id, in: database)
            var edited = current
            change(&edited)
            edited.id = current.id
            edited.doneAt = current.doneAt
            edited.position = current.position
            edited.createdAt = current.createdAt
            edited.updatedAt = current.updatedAt
            edited.repeatSeriesID = current.repeatSeriesID
            edited.dueAt = edited.dueAt.map(LocalTime.truncated)

            let moved = edited.list != current.list
            var unmoved = edited
            unmoved.list = current.list
            let changed = unmoved != current
            guard moved || changed else { return current }

            edited.updatedAt = at
            try edited.update(database)
            if moved {
                try Self.log(.moved, on: id, at: at, in: database)
            }
            if changed {
                try Self.log(.edited, on: id, at: at, in: database)
            }
            return edited
        }
    }

    static let manualOrderKey = AppStateKey(name: "manual_order", defaultValue: false)

    func adoptManualOrder() throws {
        guard !value(for: Self.manualOrderKey) else { return }
        let keyName = Self.manualOrderKey.name
        try write { database in
            try database.execute(sql: """
                UPDATE priority SET position = (
                    SELECT rank FROM (
                        SELECT id, ROW_NUMBER() OVER (
                            ORDER BY
                                done_at IS NOT NULL,
                                CASE WHEN done_at IS NULL THEN
                                    CASE level WHEN 'high' THEN 0 WHEN 'medium' THEN 1 ELSE 2 END
                                END,
                                CASE WHEN done_at IS NULL THEN due_at IS NULL END,
                                CASE WHEN done_at IS NULL THEN due_at END,
                                position,
                                id
                        ) AS rank FROM priority
                    ) ranked WHERE ranked.id = priority.id
                )
                """)
            try database.execute(
                sql: """
                    INSERT INTO app_state (key, value) VALUES (?, 'true')
                    ON CONFLICT (key) DO UPDATE SET value = excluded.value
                    """,
                arguments: [keyName]
            )
        }
    }

    func reorderPriorities(_ ids: [Priority.ID]) throws {
        try write { database in
            var slots: [Int] = []
            for id in ids {
                slots.append(try Self.priority(id, in: database).position)
            }
            slots.sort()
            for (id, position) in zip(ids, slots) {
                try database.execute(sql: "UPDATE priority SET position = ? WHERE id = ?", arguments: [position, id])
            }
        }
    }

    @discardableResult
    func markDone(_ id: Priority.ID) throws -> Priority {
        let at = timestamp()
        return try write { database in
            var priority = try Self.priority(id, in: database)
            guard priority.doneAt == nil else { return priority }
            priority.doneAt = at
            priority.updatedAt = at
            try priority.update(database)
            try Self.log(.done, on: id, at: at, in: database)
            return priority
        }
    }

    @discardableResult
    func restorePriority(_ id: Priority.ID) throws -> Priority {
        let at = timestamp()
        return try write { database in
            var priority = try Self.priority(id, in: database)
            guard priority.doneAt != nil else { return priority }
            let openCopies = try Self.openCopies(ofSeries: priority.seriesID, in: database)
            if try Self.personChanged(openCopies, in: database) {
                priority.repeatRule = .none
                priority.repeatSeriesID = UUID().uuidString
            } else {
                for copy in openCopies {
                    try copy.delete(database)
                }
            }
            priority.doneAt = nil
            priority.updatedAt = at
            try priority.update(database)
            try Self.log(.restored, on: id, at: at, in: database)
            return priority
        }
    }

    @discardableResult
    func deletePriority(_ id: Priority.ID) throws -> Priority {
        let at = timestamp()
        return try write { database in
            let priority = try Self.priority(id, in: database)
            try priority.delete(database)
            if !priority.isDone {
                try Self.endSeries(priority.seriesID, at: at, in: database)
            }
            return priority
        }
    }

    @discardableResult
    func addRepeatCopies() throws -> [Priority] {
        let at = timestamp()
        return try write { database in
            let priorities = try Priority.fetchAll(database)
            let subtasks = Dictionary(grouping: try Subtask.fetchAll(database), by: \.priorityID)
            var position = priorities.map(\.position).max() ?? 0
            return try RepeatPlanner.copies(of: priorities, subtasks: subtasks, now: at).map { copy in
                position += 1
                let priority = Priority(
                    id: UUID().uuidString,
                    title: copy.title,
                    note: copy.note,
                    level: copy.level,
                    list: .today,
                    dueAt: copy.dueAt.map(LocalTime.truncated),
                    doneAt: nil,
                    position: position,
                    createdAt: at,
                    updatedAt: at,
                    repeatRule: .daily,
                    repeatSeriesID: copy.seriesID
                )
                try priority.insert(database)
                for (index, title) in copy.subtaskTitles.enumerated() {
                    try Subtask(
                        id: UUID().uuidString,
                        priorityID: priority.id,
                        title: title,
                        doneAt: nil,
                        position: index + 1,
                        createdAt: at
                    ).insert(database)
                }
                try Self.log(.created, on: priority.id, at: at, in: database)
                return priority
            }
        }
    }

    @discardableResult
    func addSubtask(to priorityID: Priority.ID, title: String) throws -> Subtask {
        let at = timestamp()
        return try write { database in
            _ = try Self.priority(priorityID, in: database)
            let lastPosition = try Int.fetchOne(
                database,
                sql: "SELECT MAX(position) FROM subtask WHERE priority_id = ?",
                arguments: [priorityID]
            ) ?? 0
            let subtask = Subtask(
                id: UUID().uuidString,
                priorityID: priorityID,
                title: title,
                doneAt: nil,
                position: lastPosition + 1,
                createdAt: at
            )
            try subtask.insert(database)
            try Self.log(.edited, on: priorityID, at: at, in: database)
            return subtask
        }
    }

    @discardableResult
    func toggleSubtask(_ id: Subtask.ID) throws -> Subtask {
        let at = timestamp()
        return try write { database in
            var subtask = try Self.subtask(id, in: database)
            subtask.doneAt = subtask.isDone ? nil : at
            try subtask.update(database)
            try Self.log(subtask.isDone ? .subtaskDone : .edited, on: subtask.priorityID, at: at, in: database)
            return subtask
        }
    }

    @discardableResult
    func renameSubtask(_ id: Subtask.ID, title: String) throws -> Subtask {
        let at = timestamp()
        return try write { database in
            var subtask = try Self.subtask(id, in: database)
            guard subtask.title != title else { return subtask }
            subtask.title = title
            try subtask.update(database)
            try Self.log(.edited, on: subtask.priorityID, at: at, in: database)
            return subtask
        }
    }

    @discardableResult
    func deleteSubtask(_ id: Subtask.ID) throws -> Subtask {
        let at = timestamp()
        return try write { database in
            let subtask = try Self.subtask(id, in: database)
            try subtask.delete(database)
            try Self.log(.edited, on: subtask.priorityID, at: at, in: database)
            return subtask
        }
    }

    @discardableResult
    func addNote(body: String = "") throws -> NoteItem {
        let at = timestamp()
        let note = NoteItem(id: UUID().uuidString, body: body, createdAt: at, updatedAt: at)
        try write { database in try note.insert(database) }
        return note
    }

    @discardableResult
    func editNote(_ id: NoteItem.ID, body: String) throws -> NoteItem {
        let at = timestamp()
        return try write { database in
            var note = try Self.note(id, in: database)
            guard note.body != body else { return note }
            note.body = body
            note.updatedAt = at
            try note.update(database)
            return note
        }
    }

    @discardableResult
    func deleteNote(_ id: NoteItem.ID) throws -> NoteItem {
        try write { database in
            let note = try Self.note(id, in: database)
            try note.delete(database)
            return note
        }
    }

    func restoreNote(_ note: NoteItem) throws {
        try write { database in try note.save(database) }
    }

    func setValue<Value>(_ value: Value, for key: AppStateKey<Value>) throws {
        let text = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        try write { database in
            try database.execute(
                sql: """
                    INSERT INTO app_state (key, value) VALUES (?, ?)
                    ON CONFLICT (key) DO UPDATE SET value = excluded.value
                    """,
                arguments: [key.name, text]
            )
        }
    }

    func saveAlerts(_ alerts: [PriorityAlert]) throws {
        guard !alerts.isEmpty else { return }
        try write { database in
            for alert in alerts {
                try database.execute(
                    sql: """
                        INSERT INTO alert (id, priority_id, kind, fire_at, status)
                        SELECT ?, ?, ?, ?, ? WHERE EXISTS (SELECT 1 FROM priority WHERE id = ?)
                        ON CONFLICT (id) DO UPDATE SET fire_at = excluded.fire_at, status = excluded.status
                        """,
                    arguments: [
                        alert.id,
                        alert.priorityID,
                        alert.kind,
                        LocalTime.text(from: alert.fireAt),
                        alert.status,
                        alert.priorityID,
                    ]
                )
            }
        }
    }

    private func timestamp() -> Date {
        LocalTime.truncated(now())
    }

    private func write<Value: Sendable>(
        _ updates: @Sendable (Database) throws -> Value
    ) throws -> Value {
        let result = try database.write(updates)
        apply(try database.read { try StoreSnapshot.fetch($0) })
        return result
    }

    private func apply(_ fresh: StoreSnapshot) {
        if fresh != snapshot {
            snapshot = fresh
        }
    }

    private nonisolated static func priority(_ id: Priority.ID, in database: Database) throws -> Priority {
        guard let priority = try Priority.fetchOne(database, key: id) else {
            throw AppStoreError.priorityNotFound(id)
        }
        return priority
    }

    private nonisolated static func note(_ id: NoteItem.ID, in database: Database) throws -> NoteItem {
        guard let note = try NoteItem.fetchOne(database, key: id) else {
            throw AppStoreError.noteNotFound(id)
        }
        return note
    }

    private nonisolated static func subtask(_ id: Subtask.ID, in database: Database) throws -> Subtask {
        guard let subtask = try Subtask.fetchOne(database, key: id) else {
            throw AppStoreError.subtaskNotFound(id)
        }
        return subtask
    }

    private nonisolated static func openCopies(ofSeries seriesID: String, in database: Database) throws -> [Priority] {
        try Priority.fetchAll(
            database,
            sql: "SELECT * FROM priority WHERE COALESCE(repeat_series_id, id) = ? AND done_at IS NULL ORDER BY position, id",
            arguments: [seriesID]
        )
    }

    private nonisolated static func personChanged(_ priorities: [Priority], in database: Database) throws -> Bool {
        try priorities.contains { priority in
            try Bool.fetchOne(
                database,
                sql: "SELECT EXISTS (SELECT 1 FROM priority_event WHERE priority_id = ? AND type <> 'created')",
                arguments: [priority.id]
            ) ?? false
        }
    }

    private nonisolated static func endSeries(_ seriesID: String, at: Date, in database: Database) throws {
        let ids = try String.fetchAll(
            database,
            sql: """
                SELECT id FROM priority
                WHERE COALESCE(repeat_series_id, id) = ? AND repeat_rule <> 'none'
                ORDER BY position, id
                """,
            arguments: [seriesID]
        )
        for id in ids {
            try database.execute(sql: "UPDATE priority SET repeat_rule = 'none' WHERE id = ?", arguments: [id])
            try log(.edited, on: id, at: at, in: database)
        }
    }

    private nonisolated static func log(
        _ type: PriorityEventType,
        on priorityID: Priority.ID,
        at: Date,
        in database: Database
    ) throws {
        try PriorityEvent(id: nil, priorityID: priorityID, at: at, type: type).insert(database)
        try database.execute(
            sql: "UPDATE priority SET updated_at = ? WHERE id = ?",
            arguments: [LocalTime.text(from: at), priorityID]
        )
    }
}
