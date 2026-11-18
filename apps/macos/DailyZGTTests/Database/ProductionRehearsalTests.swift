import CryptoKit
import Foundation
import GRDB
import Testing
@testable import DailyZGT

@Suite(.serialized)
@MainActor
struct ProductionRehearsalTests {
    nonisolated static let path = ProcessInfo.processInfo.environment["DAILYZGT_REHEARSAL_DB"].flatMap { $0.isEmpty ? nil : $0 }
    nonisolated static let keptTables = ["priority", "subtask", "alert", "priority_event", "app_state"]

    private struct Facts: Equatable {
        var counts: [String: Int]
        var noteRows: [String]
        var filledNoteHashes: [String]
    }

    private static func hash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func facts(_ database: Database) throws -> Facts {
        var counts: [String: Int] = [:]
        for table in keptTables + ["note"] {
            counts[table] = try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM \(table)") ?? -1
        }
        let notes = try Row.fetchAll(database, sql: "SELECT scope, period, body, updated_at FROM note ORDER BY scope, period")
        let rows = notes.map { row -> String in
            let body: String = row["body"]
            let scope: String = row["scope"]
            let period: String = row["period"]
            let updatedAt: String = row["updated_at"]
            return [scope, period, updatedAt, hash(body)].joined(separator: "|")
        }
        let filled = notes.compactMap { row -> String? in
            let body: String = row["body"]
            return body.allSatisfy(\.isWhitespace) ? nil : hash(body)
        }
        return Facts(counts: counts, noteRows: rows, filledNoteHashes: filled.sorted())
    }

    private static func integrity(_ database: Database) throws -> [String] {
        try String.fetchAll(database, sql: "PRAGMA integrity_check")
    }

    @Test(.enabled(if: path != nil))
    func theProductionCopyMigratesWithoutLosingData() throws {
        let url = URL(filePath: try #require(Self.path))
        var report: [String: Any] = [:]

        let old = try DatabaseQueue(path: url.path)
        let before = try old.read { database in
            (try Self.facts(database), try Self.integrity(database),
             try String.fetchAll(database, sql: "SELECT identifier FROM grdb_migrations ORDER BY identifier"))
        }
        try old.close()
        #expect(before.1 == ["ok"])
        #expect(before.2 == ["001_create_tables", "002_add_repeat_to_priority"])

        let migrated = try AppDatabase.onDisk(at: url)
        let after = try migrated.read { database in
            (try Self.facts(database), try Self.integrity(database),
             try String.fetchAll(database, sql: "SELECT identifier FROM grdb_migrations ORDER BY identifier"),
             try String.fetchAll(database, sql: "SELECT body FROM note_item").map(Self.hash).sorted(),
             try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM image"),
             try StoreSnapshot.fetch(database))
        }
        #expect(after.1 == ["ok"])
        #expect(after.2 == ["001_create_tables", "002_add_repeat_to_priority", "003_add_image", "004_add_note_item", "005_add_soft_delete"])
        #expect(after.0 == before.0)
        #expect(after.3 == before.0.filledNoteHashes)
        #expect(after.4 == 0)
        #expect(after.5.open.count + after.5.done.count == before.0.counts["priority"])
        #expect(after.5.subtasks.values.map(\.count).reduce(0, +) == before.0.counts["subtask"])
        #expect(after.5.noteItems.count == before.0.filledNoteHashes.count)

        let store = AppStore(database: migrated)
        try store.adoptManualOrder()
        let removedAtLaunch = try store.images.deleteOrphans(olderThan: store.now().addingTimeInterval(-NoteImageStore.orphanAge))
        #expect(removedAtLaunch == 0)
        let booted = try migrated.read { try Self.facts($0) }
        #expect(booted.noteRows == before.0.noteRows)
        for table in ["priority", "subtask", "alert", "priority_event", "note"] {
            #expect(booted.counts[table] == before.0.counts[table])
        }

        let probe = try DatabaseQueue()
        try migrated.backup(to: probe)
        try migrated.close()
        let probeImages = NoteImageStore(database: probe)
        let image = EncodedImage(mime: "image/png", width: 1, height: 1, bytes: Data([0x89, 0x50, 0x4E, 0x47]))
        let longAgo = Date().addingTimeInterval(-3 * 24 * 60 * 60)
        let inNoteItem = try probeImages.insert(image, now: longAgo)
        let inPriority = try probeImages.insert(image, now: longAgo)
        let orphan = try probeImages.insert(image, now: longAgo)
        let fresh = try probeImages.insert(image, now: Date())
        try probe.write { database in
            try database.execute(
                sql: "UPDATE note_item SET body = body || ? WHERE id = (SELECT id FROM note_item ORDER BY created_at LIMIT 1)",
                arguments: ["\n" + NoteImageStore.markdown(for: inNoteItem)]
            )
            try database.execute(
                sql: "UPDATE priority SET note = note || ? WHERE id = (SELECT id FROM priority ORDER BY id LIMIT 1)",
                arguments: ["\n" + NoteImageStore.markdown(for: inPriority)]
            )
        }
        let removedInProbe = try probeImages.deleteOrphans(olderThan: Date().addingTimeInterval(-NoteImageStore.orphanAge))
        let left = Set(try values("SELECT id FROM image", in: probe, as: String.self))
        #expect(removedInProbe == 1)
        #expect(left == [inNoteItem, inPriority, fresh])
        #expect(!left.contains(orphan))

        report["integrityBefore"] = before.1
        report["integrityAfter"] = after.1
        report["migrationsAfter"] = after.2
        report["countsBefore"] = before.0.counts
        report["countsAfterBoot"] = booted.counts
        report["noteRowsUnchanged"] = after.0.noteRows == before.0.noteRows
        report["filledOldNotes"] = before.0.filledNoteHashes.count
        report["noteItems"] = after.3.count
        report["noteItemHashesMatch"] = after.3 == before.0.filledNoteHashes
        report["imageRows"] = after.4 ?? -1
        report["snapshotPriorities"] = after.5.open.count + after.5.done.count
        report["snapshotNoteItems"] = after.5.noteItems.count
        report["removedAtLaunch"] = removedAtLaunch
        report["probeRemoved"] = removedInProbe
        report["probeKeptReferenced"] = left.isSuperset(of: [inNoteItem, inPriority])
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url.appendingPathExtension("report.json"))
    }
}
