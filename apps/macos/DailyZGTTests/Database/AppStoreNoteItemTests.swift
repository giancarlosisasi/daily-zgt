import Foundation
import GRDB
import os
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct AppStoreNoteItemTests {
    let clock = TestClock("2026-11-17T16:20:00")

    @Test
    func addWritesOneNoteWithTheClockTime() throws {
        let store = try makeStore(clock)
        let note = try store.addNote(body: "# Reunión con ventas")
        #expect(UUID(uuidString: note.id) != nil)
        #expect(store.note(id: note.id) == note)
        let row: [String] = try values("SELECT body || '|' || created_at || '|' || updated_at FROM note_item", in: store.database)
        #expect(row == ["# Reunión con ventas|2026-11-17T16:20:00|2026-11-17T16:20:00"])
    }

    @Test
    func editChangesTheBodyAndTheUpdateTimeOnly() throws {
        let store = try makeStore(clock)
        let note = try store.addNote()
        clock.advance(minutes: 5)
        let edited = try store.editNote(note.id, body: "Nuevo texto")
        #expect(edited.body == "Nuevo texto")
        #expect(edited.createdAt == note.createdAt)
        #expect(edited.updatedAt == localDate("2026-11-17T16:25:00"))
        clock.advance(minutes: 5)
        let same = try store.editNote(note.id, body: "Nuevo texto")
        #expect(same.updatedAt == localDate("2026-11-17T16:25:00"))
    }

    @Test
    func deleteKeepsTheRowAndRestoreBringsItBack() throws {
        let store = try makeStore(clock)
        let note = try store.addNote(body: "Borrar y volver")
        clock.advance(minutes: 3)
        let deleted = try store.deleteNote(note.id)
        #expect(deleted.id == note.id)
        #expect(deleted.deletedAt == localDate("2026-11-17T16:23:00"))
        #expect(deleted.updatedAt == note.updatedAt)
        #expect(store.note(id: note.id) == nil)
        #expect(store.deletedNotes.map(\.id) == [note.id])
        #expect(store.noteIncludingDeleted(id: note.id) == deleted)
        let rows: [String] = try values("SELECT deleted_at FROM note_item", in: store.database)
        #expect(rows == ["2026-11-17T16:23:00"])
        try store.restoreDeletedNote(note.id)
        #expect(store.note(id: note.id) == note)
        #expect(store.deletedNotes.isEmpty)
    }

    @Test
    func aMissingNoteThrows() throws {
        let store = try makeStore(clock)
        #expect(throws: AppStoreError.noteNotFound("x")) { try store.editNote("x", body: "a") }
        #expect(throws: AppStoreError.noteNotFound("x")) { try store.deleteNote("x") }
    }

    @Test
    func theSnapshotListsTheNewestNoteFirst() throws {
        let store = try makeStore(clock)
        let first = try store.addNote(body: "Primera")
        clock.advance(minutes: 1)
        let second = try store.addNote(body: "Segunda")
        #expect(store.snapshot.noteItems.map(\.id) == [second.id, first.id])
    }

    @Test
    func theSnapshotReadsTheBodyButNeverTheImageBytes() throws {
        let store = try makeStore(clock)
        try store.addNote(body: "Ver ![](zgt-image:abc)")
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
        #expect(all.contains { $0.contains("FROM note_item") })
        #expect(all.allSatisfy { !$0.contains("FROM image") && !$0.contains("bytes") })
    }
}
