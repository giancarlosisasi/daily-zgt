import Foundation
import GRDB
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct AppStoreObservationTests {
    static let insertPriority = """
        INSERT INTO priority (id, title, level, list, position, created_at, updated_at)
        VALUES ('p1', 'From another writer', 'high', 'today', 1, '2026-10-12T09:00:00', '2026-10-12T09:00:00')
        """

    @Test(.timeLimit(.minutes(1)))
    func aStoreWriteChangesThePublishedValue() async throws {
        let store = try makeStore()
        #expect(store.openCount(in: .today) == 0)
        try await nextChange(of: store) {
            try store.addPriority(title: "Observed", list: .today)
        }
        #expect(store.openCount(in: .today) == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func aWriteThatSkipsTheStoreChangesThePublishedValue() async throws {
        let store = try makeStore()
        try await nextChange(of: store) {
            try execute(Self.insertPriority, in: store.database)
        }
        #expect(store.openPriorities(in: .today).map(\.title) == ["From another writer"])
    }

    @Test(.timeLimit(.minutes(1)))
    func aWriteFromTheSqlite3ToolChangesThePublishedValue() async throws {
        let folder = try temporaryFolder("external-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "daily-zgt.sqlite")
        let store = AppStore(database: try AppDatabase.onDisk(at: url))

        try await nextChange(of: store) {
            let tool = Process()
            tool.executableURL = URL(filePath: "/usr/bin/sqlite3")
            tool.arguments = [url.path, Self.insertPriority]
            try tool.run()
            tool.waitUntilExit()
            #expect(tool.terminationStatus == 0)
        }
        #expect(store.openPriorities(in: .today).map(\.title) == ["From another writer"])
        #expect(store.observationError == nil)
    }
}
