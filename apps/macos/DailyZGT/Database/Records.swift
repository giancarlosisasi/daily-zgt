import Foundation
import GRDB

enum PriorityLevel: String, Codable, CaseIterable, Sendable, DatabaseValueConvertible {
    case high
    case medium
    case low
}

enum PriorityList: String, Codable, CaseIterable, Sendable, DatabaseValueConvertible {
    case today
    case week
}

enum RepeatRule: String, Codable, CaseIterable, Sendable, DatabaseValueConvertible {
    case none
    case daily
}

enum NoteScope: String, Codable, CaseIterable, Sendable, DatabaseValueConvertible {
    case day
    case week
}

enum AlertKind: String, Codable, CaseIterable, Sendable, DatabaseValueConvertible {
    case before30m = "before_30m"
    case atDue = "at_due"
    case snooze
}

enum AlertStatus: String, Codable, CaseIterable, Sendable, DatabaseValueConvertible {
    case scheduled
    case delivered
    case snoozed
    case cancelled
}

enum PriorityEventType: String, Codable, CaseIterable, Sendable, DatabaseValueConvertible {
    case created
    case edited
    case moved
    case done
    case restored
    case subtaskDone = "subtask_done"
}

protocol LocalTimeRecord: Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {}

extension LocalTimeRecord {
    static func databaseDateEncodingStrategy(for column: String) -> DatabaseDateEncodingStrategy {
        .custom { LocalTime.text(from: $0) }
    }

    static func databaseDateDecodingStrategy(for column: String) -> DatabaseDateDecodingStrategy {
        .custom { value in
            String.fromDatabaseValue(value).flatMap { LocalTime.date(from: $0) }
        }
    }
}

struct Priority: LocalTimeRecord, Identifiable {
    static let databaseTableName = "priority"

    var id: String
    var title: String
    var note: String
    var level: PriorityLevel
    var list: PriorityList
    var dueAt: Date?
    var doneAt: Date?
    var position: Int
    var createdAt: Date
    var updatedAt: Date
    var repeatRule = RepeatRule.none
    var repeatSeriesID: String?

    var isDone: Bool { doneAt != nil }
    var seriesID: String { repeatSeriesID ?? id }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case note
        case level
        case list
        case dueAt = "due_at"
        case doneAt = "done_at"
        case position
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case repeatRule = "repeat_rule"
        case repeatSeriesID = "repeat_series_id"
    }
}

struct Subtask: LocalTimeRecord, Identifiable {
    static let databaseTableName = "subtask"

    var id: String
    var priorityID: String
    var title: String
    var doneAt: Date?
    var position: Int
    var createdAt: Date

    var isDone: Bool { doneAt != nil }

    enum CodingKeys: String, CodingKey {
        case id
        case priorityID = "priority_id"
        case title
        case doneAt = "done_at"
        case position
        case createdAt = "created_at"
    }
}

struct Note: LocalTimeRecord {
    static let databaseTableName = "note"

    var scope: NoteScope
    var period: String
    var body: String
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case scope
        case period
        case body
        case updatedAt = "updated_at"
    }
}

struct PriorityAlert: LocalTimeRecord, Identifiable {
    static let databaseTableName = "alert"

    var id: String
    var priorityID: String
    var kind: AlertKind
    var fireAt: Date
    var status: AlertStatus

    enum CodingKeys: String, CodingKey {
        case id
        case priorityID = "priority_id"
        case kind
        case fireAt = "fire_at"
        case status
    }
}

struct PriorityEvent: LocalTimeRecord {
    static let databaseTableName = "priority_event"

    var id: Int64?
    var priorityID: String
    var at: Date
    var type: PriorityEventType

    enum CodingKeys: String, CodingKey {
        case id
        case priorityID = "priority_id"
        case at
        case type
    }
}

struct AppStateEntry: LocalTimeRecord {
    static let databaseTableName = "app_state"

    var key: String
    var value: String
}
