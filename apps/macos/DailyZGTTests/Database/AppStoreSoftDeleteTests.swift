import Foundation
import GRDB
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct AppStoreSoftDeleteTests {
    let clock = TestClock("2026-11-17T10:00:00")

    static let image = EncodedImage(mime: "image/png", width: 1, height: 1, bytes: Data([0x89, 0x50, 0x4E, 0x47]))

    @Test
    func aDeletedPriorityLeavesEachLiveRead() throws {
        let store = try makeStore(clock)
        try store.setValue(true, for: MenuBarTitle.key)
        let gone = try store.addPriority(title: "Se va", level: .high, list: .today, dueAt: localDate("2026-11-17T11:00:00"))
        let kept = try store.addPriority(title: "Queda", list: .today, dueAt: localDate("2026-11-17T12:00:00"))
        #expect(store.menuBarTitle == "Se va")
        #expect(store.openCount(in: .today) == 2)

        let deleted = try store.deletePriority(gone.id)

        #expect(deleted.deletedAt == clock.date)
        #expect(deleted.updatedAt == gone.updatedAt)
        #expect(store.priority(id: gone.id) == nil)
        #expect(store.priorityIncludingDeleted(id: gone.id) == deleted)
        #expect(store.openPriorities(in: .all).map(\.id) == [kept.id])
        #expect(store.openGroups(in: .today).flatMap(\.priorities).map(\.id) == [kept.id])
        #expect(store.openCount(in: .today) == 1)
        #expect(store.menuBarTitle == "Queda")
        #expect(store.snapshot.open.map(\.id) == [kept.id])
        #expect(store.snapshot.done.isEmpty)
        #expect(store.deletedPriorities.map(\.id) == [gone.id])
        #expect(try values("SELECT deleted_at FROM priority WHERE id = '\(gone.id)'", in: store.database) == ["2026-11-17T10:00:00"])
    }

    @Test
    func aDeletedPriorityFreesItsPlaceInTheTodayLimit() throws {
        let store = try makeStore(clock)
        try store.setValue(true, for: TodayLimit.key)
        var ids: [Priority.ID] = []
        for index in 1...TodayLimit.maxOpen {
            ids.append(try store.addPriority(title: "P\(index)", list: .today, dueAt: localDate("2026-11-17T18:00:00")).id)
        }
        #expect(store.addBlock(forDue: nil) == TodayLimit.message)

        try store.deletePriority(ids[0])
        #expect(store.addBlock(forDue: nil) == nil)

        try store.restoreDeletedPriority(ids[0])
        #expect(store.addBlock(forDue: nil) == TodayLimit.message)
    }

    @Test
    func aDeletedDonePriorityLeavesHechasAndTheHistory() throws {
        let store = try makeStore(clock)
        let recent = try store.addPriority(title: "Reciente", list: .today)
        try store.markDone(recent.id)
        let old = try store.addPriority(title: "Vieja", list: .today)
        clock.date = localDate("2026-11-14T09:00:00")
        try store.markDone(old.id)
        clock.date = localDate("2026-11-17T10:00:00")
        #expect(store.donePriorities(in: .today).map(\.id) == [recent.id])
        #expect(store.olderDonePriorities(outside: .today).map(\.id) == [old.id])

        try store.deletePriority(recent.id)
        clock.advance(minutes: 1)
        try store.deletePriority(old.id)

        #expect(store.donePriorities(in: .today).isEmpty)
        #expect(store.olderDonePriorities(outside: .today).isEmpty)
        #expect(store.deletedPriorities.map(\.id) == [old.id, recent.id])

        try store.restoreDeletedPriority(recent.id)

        #expect(store.donePriorities(in: .today).map(\.id) == [recent.id])
        #expect(store.priority(id: recent.id)?.isDone == true)
        #expect(store.deletedPriorities.map(\.id) == [old.id])
    }

    @Test
    func aDeletedPriorityTakesNoEdit() throws {
        let store = try makeStore(clock)
        let gone = try store.addPriority(title: "Se va", list: .today)
        try store.deletePriority(gone.id)
        let missing = AppStoreError.priorityNotFound(gone.id)

        #expect(throws: missing) { try store.markDone(gone.id) }
        #expect(throws: missing) { try store.editPriority(gone.id) { $0.title = "Otro" } }
        #expect(throws: missing) { try store.addSubtask(to: gone.id, title: "Una") }
        #expect(throws: missing) { try store.restorePriority(gone.id) }
        #expect(throws: missing) { try store.reorderPriorities([gone.id]) }
        #expect(throws: missing) { try store.deletePriority(gone.id) }

        let live = try store.addPriority(title: "Viva", list: .today)
        #expect(throws: AppStoreError.priorityNotFound(live.id)) { try store.restoreDeletedPriority(live.id) }
    }

    @Test
    func restoreBringsTheOpenPriorityBackToItsPlace() throws {
        let store = try makeStore(clock)
        let first = try store.addPriority(title: "Uno", list: .today)
        let second = try store.addPriority(title: "Dos", list: .today)
        let third = try store.addPriority(title: "Tres", list: .today)
        try store.addSubtask(to: second.id, title: "Paso")
        let before = try #require(store.priority(id: second.id))
        clock.advance(minutes: 5)
        try store.deletePriority(second.id)
        #expect(store.openPriorities(in: .all).map(\.id) == [first.id, third.id])

        let restored = try store.restoreDeletedPriority(second.id)

        #expect(restored == before)
        #expect(store.openPriorities(in: .all).map(\.id) == [first.id, second.id, third.id])
        #expect(store.subtasks(of: second.id).map(\.title) == ["Paso"])
        #expect(store.deletedPriorities.isEmpty)
        #expect(try store.events(of: second.id).map(\.type) == [.created, .edited])
    }

    @Test
    func aNewPriorityGoesAfterTheDeletedOnes() throws {
        let store = try makeStore(clock)
        let first = try store.addPriority(title: "Uno", list: .today)
        let gone = try store.addPriority(title: "Se va", list: .today)
        try store.deletePriority(gone.id)
        let next = try store.addPriority(title: "Nueva", list: .today)
        #expect(next.position > gone.position)
        try store.restoreDeletedPriority(gone.id)
        #expect(store.openPriorities(in: .all).map(\.id) == [first.id, gone.id, next.id])
    }

    @Test
    func deleteForEverRemovesTheRowItsSubtasksAndItsAlertsAndKeepsTheEvents() throws {
        let store = try makeStore(clock)
        let gone = try store.addPriority(title: "Se va", list: .today, dueAt: localDate("2026-11-17T12:00:00"))
        try store.addSubtask(to: gone.id, title: "Paso")
        try store.saveAlerts([
            PriorityAlert(id: "a1", priorityID: gone.id, kind: .atDue, fireAt: localDate("2026-11-17T12:00:00"), status: .scheduled),
        ])
        try store.deletePriority(gone.id)

        try store.deletePriorityForever(gone.id)

        #expect(store.priorityIncludingDeleted(id: gone.id) == nil)
        #expect(store.deletedPriorities.isEmpty)
        #expect(try values("SELECT COUNT(*) FROM priority", in: store.database) == [0])
        #expect(try values("SELECT COUNT(*) FROM subtask", in: store.database) == [0])
        #expect(try store.alerts().isEmpty)
        #expect(try store.events(of: gone.id).map(\.type) == [.created, .edited])
        #expect(throws: AppStoreError.priorityNotFound(gone.id)) { try store.deletePriorityForever(gone.id) }
    }

    @Test
    func aDeletedNoteLeavesTheListAndEachFilter() throws {
        let store = try makeStore(clock)
        let kept = try store.addNote(body: "Queda")
        clock.advance(minutes: 1)
        let gone = try store.addNote(body: "Se va")

        try store.deleteNote(gone.id)

        for filter in [DueFilter.all, .today, .week] {
            #expect(store.notes(in: filter).map(\.id) == [kept.id])
        }
        #expect(store.note(id: gone.id) == nil)
        #expect(store.noteIncludingDeleted(id: gone.id)?.body == "Se va")
        #expect(store.snapshot.noteItems.map(\.id) == [kept.id])
        #expect(store.deletedNotes.map(\.id) == [gone.id])
        #expect(throws: AppStoreError.noteNotFound(gone.id)) { try store.editNote(gone.id, body: "Otro") }
        #expect(throws: AppStoreError.noteNotFound(gone.id)) { try store.deleteNote(gone.id) }
        #expect(throws: AppStoreError.noteNotFound(kept.id)) { try store.restoreDeletedNote(kept.id) }
    }

    @Test
    func theDeletedNotesAreNewestFirst() throws {
        let store = try makeStore(clock)
        let first = try store.addNote(body: "Primera")
        let second = try store.addNote(body: "Segunda")
        try store.deleteNote(second.id)
        clock.advance(minutes: 1)
        try store.deleteNote(first.id)
        #expect(store.deletedNotes.map(\.id) == [first.id, second.id])
    }

    @Test
    func deleteForEverRemovesTheNoteRow() throws {
        let store = try makeStore(clock)
        let gone = try store.addNote(body: "Se va")
        try store.deleteNote(gone.id)

        try store.deleteNoteForever(gone.id)

        #expect(store.noteIncludingDeleted(id: gone.id) == nil)
        #expect(store.deletedNotes.isEmpty)
        #expect(try values("SELECT COUNT(*) FROM note_item", in: store.database) == [0])
        #expect(throws: AppStoreError.noteNotFound(gone.id)) { try store.deleteNoteForever(gone.id) }
    }

    @Test
    func theImageCleanupKeepsTheImagesOfDeletedRows() throws {
        clock.date = localDate("2026-11-14T09:00:00")
        let store = try makeStore(clock)
        let inPriority = try store.images.insert(Self.image, now: clock.date)
        let inNote = try store.images.insert(Self.image, now: clock.date)
        clock.date = localDate("2026-11-17T10:00:00")
        let priority = try store.addPriority(title: "Con imagen", list: .today, note: NoteImageStore.markdown(for: inPriority))
        let note = try store.addNote(body: "# Foto\n\n\(NoteImageStore.markdown(for: inNote))")
        try store.deletePriority(priority.id)
        try store.deleteNote(note.id)
        let cutoff = clock.date.addingTimeInterval(-NoteImageStore.orphanAge)

        #expect(try store.images.deleteOrphans(olderThan: cutoff) == 0)

        try store.deletePriorityForever(priority.id)
        try store.deleteNoteForever(note.id)

        #expect(try store.images.deleteOrphans(olderThan: cutoff) == 2)
        #expect(try values("SELECT COUNT(*) FROM image", in: store.database) == [0])
    }
}
