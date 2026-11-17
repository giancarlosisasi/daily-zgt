import Foundation
import GRDB
import os
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct NoteImageStoreTests {
    let sample = EncodedImage(mime: "image/png", width: 4, height: 3, bytes: TestImages.png(width: 4, height: 3, alpha: true))

    @Test
    func theMigrationAddsTheImageTableWithItsChecks() throws {
        let database = try AppDatabase.inMemory()
        let migrations: [String] = try values("SELECT identifier FROM grdb_migrations ORDER BY identifier", in: database)
        #expect(migrations.contains("003_add_image"))
        #expect(throws: (any Error).self) {
            try execute(
                "INSERT INTO image (id, mime, width, height, bytes, created_at) VALUES ('x', 'image/gif', 1, 1, x'00', '2026-10-12T09:00:00')",
                in: database
            )
        }
    }

    @Test
    func insertWritesOneRowWithTheEncodedImage() throws {
        let clock = TestClock("2026-10-12T09:00:00")
        let store = try makeStore(clock)
        let id = try store.images.insert(sample, now: clock.date)
        #expect(id == id.lowercased())
        #expect(UUID(uuidString: id) != nil)
        #expect(try store.images.encoded(id: id) == sample)
        let createdAt = try store.database.read {
            try String.fetchOne($0, sql: "SELECT created_at FROM image WHERE id = ?", arguments: [id])
        }
        #expect(createdAt == "2026-10-12T09:00:00")
        #expect(store.images.version == 1)
    }

    @Test
    func theMarkdownReferenceUsesTheZgtImageScheme() {
        #expect(NoteImageStore.markdown(for: "abc") == "![](zgt-image:abc)")
        #expect(NoteImageStore.id(fromReference: "zgt-image:abc") == "abc")
        #expect(NoteImageStore.id(fromReference: "https://example.com/a.png") == nil)
        #expect(NoteImageStore.id(fromReference: "zgt-image:") == nil)
    }

    @Test
    func theImageLoadsLazilyByIDAndOnlyOnce() throws {
        let clock = TestClock()
        let store = try makeStore(clock)
        let id = try store.images.insert(sample, now: clock.date)
        #expect(store.images.loadCount == 0)
        let first = try #require(store.images.image(reference: "zgt-image:\(id)"))
        let second = try #require(store.images.image(id: id))
        #expect(first === second)
        #expect(store.images.loadCount == 1)
        #expect(store.images.image(id: "missing") == nil)
    }

    @Test
    func theStoreSnapshotNeverReadsTheImageTable() throws {
        let clock = TestClock()
        let store = try makeStore(clock)
        try store.images.insert(sample, now: clock.date)
        let statements = OSAllocatedUnfairLock(initialState: [String]())
        try store.database.read { database in
            database.trace { event in
                let text = event.expandedDescription
                statements.withLock { $0.append(text) }
            }
            _ = try StoreSnapshot.fetch(database)
            database.trace(options: [], nil)
        }
        let all = statements.withLock { $0 }
        #expect(!all.isEmpty)
        #expect(all.allSatisfy { !$0.contains("image") })
    }

    @Test
    func cleanupDeletesOnlyOldImagesThatNoNoteUses() throws {
        let clock = TestClock("2026-10-10T09:00:00")
        let store = try makeStore(clock)
        let inPriority = try store.images.insert(sample, now: clock.date)
        let inNote = try store.images.insert(sample, now: clock.date)
        let inNoteItem = try store.images.insert(sample, now: clock.date)
        let orphan = try store.images.insert(sample, now: clock.date)
        clock.date = localDate("2026-10-12T08:00:00")
        let fresh = try store.images.insert(sample, now: clock.date)
        _ = try store.addPriority(title: "Con imagen", level: .high, list: .today, note: "Antes\n\n\(NoteImageStore.markdown(for: inPriority))\n")
        try execute(
            "INSERT INTO note (scope, period, body, updated_at) VALUES ('day', '2026-10-12', 'Ver ![](zgt-image:\(inNote))', '2026-10-12T08:00:00')",
            in: store.database
        )
        try store.addNote(body: "# Reunión\n\n\(NoteImageStore.markdown(for: inNoteItem))")
        let removed = try store.images.deleteOrphans(olderThan: clock.date.addingTimeInterval(-NoteImageStore.orphanAge))
        #expect(removed == 1)
        let kept: [String] = try values("SELECT id FROM image ORDER BY id", in: store.database)
        #expect(kept == [inPriority, inNote, inNoteItem, fresh].sorted())
        #expect(!kept.contains(orphan))
    }
}
