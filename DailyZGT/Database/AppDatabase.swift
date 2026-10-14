import Foundation
import GRDB

enum AppDatabase {
    static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "DailyZGT/daily-zgt.sqlite")
    }

    static var isTestHost: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static func forApp() throws -> DatabaseQueue {
        isTestHost ? try inMemory() : try onDisk(at: defaultURL)
    }

    static func onDisk(at url: URL) throws -> DatabaseQueue {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var configuration = Configuration()
        configuration.journalMode = .wal
        configuration.foreignKeysEnabled = true
        configuration.busyMode = .timeout(2)
        return try migrated(DatabaseQueue(path: url.path, configuration: configuration))
    }

    static func inMemory() throws -> DatabaseQueue {
        try migrated(DatabaseQueue())
    }

    private static func migrated(_ queue: DatabaseQueue) throws -> DatabaseQueue {
        try Schema.migrator.migrate(queue)
        return queue
    }
}
