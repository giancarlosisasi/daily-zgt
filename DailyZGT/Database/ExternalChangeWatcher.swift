import Foundation
import GRDB
import os

final class ExternalChangeWatcher {
    private let source: any DispatchSourceFileSystemObject

    init?(database: DatabaseQueue) {
        guard database.path != ":memory:" else { return nil }
        let descriptor = open(database.path + "-wal", O_EVTONLY)
        guard descriptor >= 0 else { return nil }

        let lastVersion = OSAllocatedUnfairLock(initialState: Self.dataVersion(of: database))
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend],
            queue: DispatchQueue(label: "com.giancarlosisasi.dailyzgt.external-changes")
        )
        source.setEventHandler {
            let version = Self.dataVersion(of: database)
            let changed = lastVersion.withLock { last in
                defer { last = version }
                return last != version
            }
            guard changed else { return }
            try? database.write { try $0.notifyChanges(in: .fullDatabase) }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
    }

    deinit {
        source.cancel()
    }

    private static func dataVersion(of database: DatabaseQueue) -> Int? {
        try? database.read { try Int.fetchOne($0, sql: "PRAGMA data_version") }
    }
}
