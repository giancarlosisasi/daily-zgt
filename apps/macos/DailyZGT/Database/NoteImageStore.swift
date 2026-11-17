import AppKit
import GRDB
import os

struct EncodedImage: Equatable, Sendable {
    var mime: String
    var width: Int
    var height: Int
    var bytes: Data
}

final class NoteImageStore: Sendable {
    static let scheme = "zgt-image:"
    static let orphanAge: TimeInterval = 24 * 60 * 60

    private struct Cache {
        var images: [String: NSImage] = [:]
        var version = 0
        var loads = 0
    }

    let database: DatabaseQueue
    private let cache = OSAllocatedUnfairLock(uncheckedState: Cache())

    init(database: DatabaseQueue) {
        self.database = database
    }

    static func markdown(for id: String) -> String {
        "![](\(scheme)\(id))"
    }

    static func id(fromReference reference: String) -> String? {
        guard reference.hasPrefix(scheme) else { return nil }
        let id = String(reference.dropFirst(scheme.count))
        return id.isEmpty ? nil : id
    }

    @discardableResult
    func insert(_ image: EncodedImage, now: Date) throws -> String {
        let id = UUID().uuidString.lowercased()
        try database.write { database in
            try database.execute(
                sql: "INSERT INTO image (id, mime, width, height, bytes, created_at) VALUES (?, ?, ?, ?, ?, ?)",
                arguments: [id, image.mime, image.width, image.height, image.bytes, LocalTime.text(from: now)]
            )
        }
        cache.withLockUnchecked { $0.version += 1 }
        return id
    }

    func encoded(id: String) throws -> EncodedImage? {
        try database.read { database in
            try Row.fetchOne(database, sql: "SELECT mime, width, height, bytes FROM image WHERE id = ?", arguments: [id])
                .map { EncodedImage(mime: $0["mime"], width: $0["width"], height: $0["height"], bytes: $0["bytes"]) }
        }
    }

    func image(id: String) -> NSImage? {
        if let cached = cache.withLockUnchecked({ $0.images[id] }) {
            return cached
        }
        cache.withLockUnchecked { $0.loads += 1 }
        guard let stored = try? encoded(id: id), let image = NSImage(data: stored.bytes) else { return nil }
        cache.withLockUnchecked { $0.images[id] = image }
        return image
    }

    func image(reference: String) -> NSImage? {
        Self.id(fromReference: reference).flatMap(image(id:))
    }

    var version: Int {
        cache.withLockUnchecked { $0.version }
    }

    var loadCount: Int {
        cache.withLockUnchecked { $0.loads }
    }

    @discardableResult
    func deleteOrphans(olderThan cutoff: Date) throws -> Int {
        let removed = try database.write { database in
            try database.execute(
                sql: """
                    DELETE FROM image
                    WHERE created_at < ?
                    AND NOT EXISTS (SELECT 1 FROM priority WHERE instr(priority.note, ? || image.id) > 0)
                    AND NOT EXISTS (SELECT 1 FROM note WHERE instr(note.body, ? || image.id) > 0)
                    AND NOT EXISTS (SELECT 1 FROM note_item WHERE instr(note_item.body, ? || image.id) > 0)
                    """,
                arguments: [LocalTime.text(from: cutoff), Self.scheme, Self.scheme, Self.scheme]
            )
            return database.changesCount
        }
        if removed > 0 {
            cache.withLockUnchecked { $0.images.removeAll() }
        }
        return removed
    }
}
