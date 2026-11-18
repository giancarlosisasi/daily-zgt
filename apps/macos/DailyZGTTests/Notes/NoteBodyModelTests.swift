import Foundation
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct NoteBodyModelTests {
    let clock = TestClock("2026-11-17T09:00:00")
    let recorder = ScheduleRecorder()

    private func makeModel(_ store: AppStore, _ note: NoteItem) -> NoteBodyModel {
        NoteBodyModel(store: store, noteID: note.id, schedule: recorder.schedule)
    }

    @Test
    func theModelStartsWithTheSavedBody() throws {
        let store = try makeStore(clock)
        let note = try store.addNote(body: "Guardado")
        #expect(makeModel(store, note).text == "Guardado")
    }

    @Test
    func typingThenWaitingSavesOnce() throws {
        let store = try makeStore(clock)
        let note = try store.addNote()
        let model = makeModel(store, note)
        model.edit("H")
        model.edit("Hola")
        #expect(recorder.entries.map(\.delay) == [.milliseconds(400), .milliseconds(400)])
        recorder.fire(0)
        #expect(store.note(id: note.id)?.body == "")
        recorder.fire(1)
        #expect(store.note(id: note.id)?.body == "Hola")
        #expect(!model.hasUnsavedEdit)
    }

    @Test
    func aFlushSavesAtOnce() throws {
        let store = try makeStore(clock)
        let note = try store.addNote()
        let model = makeModel(store, note)
        model.edit("Cerrar el panel")
        model.flush()
        #expect(store.note(id: note.id)?.body == "Cerrar el panel")
        recorder.fire(0)
        #expect(!model.hasUnsavedEdit)
    }

    @Test(.timeLimit(.minutes(1)))
    func anExternalChangeShowsOnlyWhenThePersonIsNotEditing() async throws {
        let store = try makeStore(clock)
        let note = try store.addNote(body: "Antes")
        let model = makeModel(store, note)
        try await nextChange(of: store) {
            try execute("UPDATE note_item SET body = 'Desde sqlite3' WHERE id = '\(note.id)'", in: store.database)
        }
        model.sync()
        #expect(model.text == "Desde sqlite3")
        model.edit("Mi borrador")
        try await nextChange(of: store) {
            try execute("UPDATE note_item SET body = 'Otra vez' WHERE id = '\(note.id)'", in: store.database)
        }
        model.sync()
        #expect(model.text == "Mi borrador")
    }

    @Test
    func leavingAnEmptyNoteDeletesIt() throws {
        let store = try makeStore(clock)
        let note = try store.addNote()
        let model = makeModel(store, note)
        model.edit("x")
        model.edit(" \n ")
        model.leave()
        #expect(store.note(id: note.id) == nil)
    }

    @Test
    func leavingANoteWithUnsavedTextSavesItAndKeepsIt() throws {
        let store = try makeStore(clock)
        let note = try store.addNote()
        let model = makeModel(store, note)
        model.edit("Texto que aún no se guardó")
        model.leave()
        #expect(store.note(id: note.id)?.body == "Texto que aún no se guardó")
    }

    @Test
    func aDeletedNoteIgnoresTheLastFlush() throws {
        let store = try makeStore(clock)
        let note = try store.addNote(body: "Algo")
        let model = makeModel(store, note)
        model.edit("Más")
        try store.deleteNote(note.id)
        model.flush()
        model.leave()
        #expect(!model.writeFailed)
        #expect(store.note(id: note.id) == nil)
    }

    @Test
    func aFailedWriteKeepsTheEditAndRaisesTheFlag() throws {
        let store = try makeStore(clock)
        let note = try store.addNote(body: "Algo")
        let model = makeModel(store, note)
        try execute("CREATE TRIGGER block BEFORE UPDATE ON note_item BEGIN SELECT RAISE(ABORT, 'no'); END", in: store.database)
        model.edit("Perdido?")
        model.flush()
        #expect(model.writeFailed)
        #expect(model.hasUnsavedEdit)
        model.leave()
        #expect(store.note(id: note.id)?.body == "Algo")
    }
}
