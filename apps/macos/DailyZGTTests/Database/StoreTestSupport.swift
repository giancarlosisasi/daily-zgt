import Foundation
import GRDB
import Observation
@testable import DailyZGT

@MainActor
final class TestClock {
    var date: Date

    init(_ text: String = "2026-10-12T09:00:00") {
        date = localDate(text)
    }

    func advance(minutes: Int) {
        date.addTimeInterval(TimeInterval(minutes * 60))
    }
}

func localDate(_ text: String) -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return formatter.date(from: text) ?? .distantPast
}

@MainActor
func makeStore(_ clock: TestClock = TestClock()) throws -> AppStore {
    AppStore(database: try AppDatabase.inMemory(), now: { clock.date })
}

@MainActor
func nextChange(of store: AppStore, after action: () throws -> Void) async throws {
    let (changes, continuation) = AsyncStream.makeStream(of: Void.self)
    withObservationTracking {
        _ = store.snapshot
    } onChange: {
        continuation.yield()
    }
    try action()
    for await _ in changes {
        break
    }
}

func values<Value: DatabaseValueConvertible>(
    _ sql: String,
    in database: DatabaseQueue,
    as type: Value.Type = Value.self
) throws -> [Value] {
    try database.read { try Value.fetchAll($0, sql: sql) }
}

func execute(_ sql: String, in database: DatabaseQueue) throws {
    try database.write { try $0.execute(sql: sql) }
}

func insert(_ record: some PersistableRecord, in database: DatabaseQueue) throws {
    try database.write { try record.insert($0) }
}

func temporaryFolder(_ name: String) throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appending(path: "DailyZGTTests/\(name)")
    try? FileManager.default.removeItem(at: folder)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
}
