import AppKit
import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct DeletedSectionTests {
    let clock = TestClock("2026-11-17T10:24:00")
    let recorder = ScheduleRecorder()

    private func sampleStore() throws -> AppStore {
        let store = try makeStore(clock)
        try store.addPriority(title: "Revisar el MR pendiente de compass.ui", level: .high, list: .today, dueAt: localDate("2026-11-17T11:00:00"))
        try store.addPriority(title: "1:1 con el equipo", list: .today)
        let done = try store.addPriority(title: "Enviar la factura", list: .today)
        try store.markDone(done.id)
        clock.date = localDate("2026-11-16T18:10:00")
        let old = try store.addPriority(title: "Leer el RFC de alertas", level: .low, list: .today)
        try store.deletePriority(old.id)
        let oldNote = try store.addNote(body: "# Ideas viejas\nUna lista que ya no sirve")
        try store.deleteNote(oldNote.id)
        clock.date = localDate("2026-11-17T09:40:00")
        let gone = try store.addPriority(title: "Pagar el hosting", list: .today)
        try store.deletePriority(gone.id)
        try store.addNote(body: "Llamar a Ana\nPreguntar por el brief")
        let note = try store.addNote(body: "# Reunión con ventas\nConfirmar la fecha de OTP")
        try store.deleteNote(note.id)
        clock.date = localDate("2026-11-17T10:24:00")
        return store
    }

    private func deletedID(_ store: AppStore, _ title: String) throws -> Priority.ID {
        try #require(store.deletedPriorities.first { $0.title == title }).id
    }

    private func defaults() -> UserDefaults {
        let name = "deleted-section-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func expectPNG(_ view: some View, named name: String) throws {
        let url = try Screenshot.writeHosted(view, named: name)
        #expect(try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) > 0)
    }

    private func panel(_ store: AppStore, _ state: PanelState) -> some View {
        PanelView().environment(store).environment(state).padding(Theme.Space.s3)
    }

    private func window(_ store: AppStore, _ state: PanelState, width: CGFloat = 980, height: CGFloat = 680) -> some View {
        MainWindowView(defaults: defaults())
            .environment(store)
            .environment(state)
            .frame(width: width, height: height)
    }

    @Test
    func theSectionIsClosedByDefaultAndItsStateIsSaved() throws {
        let store = try makeStore(clock)
        let state = PanelState(store: store)
        #expect(!state.isDeletedOpen)
        state.toggleDeleted()
        #expect(state.isDeletedOpen)
        #expect(try values("SELECT value FROM app_state WHERE key = 'deleted_open'", in: store.database) == ["true"])
        #expect(PanelState(store: AppStore(database: store.database)).isDeletedOpen)
        state.toggleDeleted()
        #expect(try values("SELECT value FROM app_state WHERE key = 'deleted_open'", in: store.database) == ["false"])
    }

    @Test
    func theCopySaysWhatEachActionDoes() {
        #expect(DeletedCopy.headerTitle == "Eliminadas")
        #expect(DoneRowKind.deleted.restoreTitle == "Restaurar")
        #expect(DoneRowKind.deleted.removeLabel == "Borrar para siempre")
        #expect(DoneRowKind.done.restoreTitle == "Regresar")
        #expect(DoneRowKind.done.removeLabel == "Quitar")
        #expect(DeletedCopy.confirmTitle == "¿Borrar para siempre?")
    }

    @Test
    func theEntriesShowEachDeletedItemNewestFirstWithItsDeleteTime() throws {
        let store = try sampleStore()
        let priorities = store.deletedPriorities.map { DeletedEntry($0) }
        #expect(priorities.map(\.title) == ["Pagar el hosting", "Leer el RFC de alertas"])
        #expect(priorities.map(\.deletedAt) == [localDate("2026-11-17T09:40:00"), localDate("2026-11-16T18:10:00")])
        let notes = store.deletedNotes.map { DeletedEntry($0) }
        #expect(notes.map(\.title) == ["Reunión con ventas", "Ideas viejas"])
        let days = DueDays(now: clock.date)
        #expect(NoteFilterLabels.rowDate(priorities[0].deletedAt, days) == "09:40")
    }

    @Test
    func restaurarBringsThePriorityBackAndHighlightsIt() throws {
        let store = try sampleStore()
        let flow = PriorityFlow(store: store, schedule: recorder.schedule)
        let id = try deletedID(store, "Pagar el hosting")

        flow.restoreDeleted(id)

        #expect(!flow.writeFailed)
        #expect(store.openPriorities(in: .all).map(\.id).contains(id))
        #expect(store.deletedPriorities.map(\.title) == ["Leer el RFC de alertas"])
        #expect(flow.highlightedID == id)
        #expect(recorder.entries.map(\.delay) == [.milliseconds(1400)])
    }

    @Test
    func borrarParaSiempreRemovesTheRow() throws {
        let store = try sampleStore()
        let flow = PriorityFlow(store: store, schedule: recorder.schedule)
        let id = try deletedID(store, "Pagar el hosting")

        flow.deleteForever(id)

        #expect(!flow.writeFailed)
        #expect(store.priorityIncludingDeleted(id: id) == nil)
        #expect(store.deletedPriorities.count == 1)
    }

    @Test
    func theTrashOfARowMovesThePriorityToEliminadas() throws {
        let store = try sampleStore()
        let flow = PriorityFlow(store: store, schedule: recorder.schedule)
        let done = try #require(store.donePriorities(in: .today).first)
        let open = try #require(store.openPriorities(in: .all).first)

        flow.delete(done.id)
        flow.delete(open.id)

        #expect(store.donePriorities(in: .today).isEmpty)
        #expect(!store.openPriorities(in: .all).contains { $0.id == open.id })
        #expect(Set(store.deletedPriorities.prefix(2).map(\.id)) == [done.id, open.id])
    }

    @Test
    func aDeletedPriorityOpensReadOnlyAndRestaurarMakesItLive() throws {
        let store = try sampleStore()
        let state = PanelState(store: store, priorityFlow: PriorityFlow(store: store, schedule: recorder.schedule))
        let id = try deletedID(store, "Pagar el hosting")

        state.openDetail(id)

        #expect(state.detailPriority?.isDeleted == true)
        #expect(state.detailOpenedDeleted)

        state.restoreDeletedFromDetail()

        #expect(state.detailPriority?.id == id)
        #expect(state.detailPriority?.isDeleted == false)
        #expect(!state.detailOpenedDeleted)
        #expect(store.priority(id: id) != nil)
    }

    @Test
    func aPriorityDeletedFromItsDetailClosesTheDetail() throws {
        let store = try sampleStore()
        let state = PanelState(store: store)
        let open = try #require(store.openPriorities(in: .all).first)
        state.openDetail(open.id)

        state.priorityFlow.delete(open.id)

        #expect(state.detailPriority == nil)
        #expect(store.deletedPriorities.first?.id == open.id)
    }

    @Test
    func aDeletedNoteHasAnUndoThatRestoresIt() throws {
        let store = try makeStore(clock)
        let state = PanelState(store: store, noteFlow: NoteFlow(store: store, schedule: recorder.schedule))
        let note = try store.addNote(body: "# Plan\nTexto")

        state.deleteNote(note.id)

        #expect(store.deletedNotes.map(\.id) == [note.id])
        #expect(state.noteFlow.undo?.title == "Plan")
        state.noteFlow.undoDelete()
        #expect(store.note(id: note.id) == note)
        #expect(store.deletedNotes.isEmpty)
    }

    @Test
    func anEmptyNoteGoesAwayForEver() throws {
        let store = try makeStore(clock)
        let state = PanelState(store: store)
        let note = try store.addNote(body: "  ")

        state.deleteNote(note.id)

        #expect(store.noteIncludingDeleted(id: note.id) == nil)
        #expect(store.deletedNotes.isEmpty)
    }

    @Test
    func anEmptyNoteLeftByThePersonGoesAwayForEver() throws {
        let store = try makeStore(clock)
        let note = try store.addNote()
        NoteBodyModel(store: store, noteID: note.id, schedule: recorder.schedule).leave()
        #expect(store.noteIncludingDeleted(id: note.id) == nil)
    }

    @Test
    func aDeletedNoteOpensReadOnlyAndRestaurarMakesItLive() throws {
        let store = try sampleStore()
        let state = PanelState(store: store, noteFlow: NoteFlow(store: store, schedule: recorder.schedule))
        let note = try #require(store.deletedNotes.first)

        state.openNote(note.id)

        #expect(state.tab == .notes)
        #expect(state.detailNote?.isDeleted == true)
        #expect(state.noteOpenedDeleted)
        let model = NoteBodyModel(store: store, noteID: note.id, schedule: recorder.schedule)
        #expect(model.text == note.body)
        model.leave()
        #expect(store.deletedNotes.map(\.id).contains(note.id))

        state.restoreDeletedNoteFromDetail()

        #expect(state.detailNote?.isDeleted == false)
        #expect(!state.noteOpenedDeleted)
        #expect(store.note(id: note.id)?.body == note.body)
    }

    @Test
    func borrarParaSiempreRemovesTheNote() throws {
        let store = try sampleStore()
        let flow = NoteFlow(store: store, schedule: recorder.schedule)
        let note = try #require(store.deletedNotes.first)

        flow.deleteForever(note.id)

        #expect(!flow.writeFailed)
        #expect(store.noteIncludingDeleted(id: note.id) == nil)
        #expect(store.deletedNotes.count == 1)
    }

    @Test
    func rendersThePanelSectionClosedAndOpen() throws {
        let store = try sampleStore()
        let state = PanelState(store: store)
        state.toggleDone()
        try expectPNG(panel(store, state), named: "deleted-section-panel-closed")
        state.toggleDeleted()
        try expectPNG(panel(store, state), named: "deleted-section-panel-open")
    }

    @Test
    func rendersARowWithTheConfirmation() throws {
        let store = try sampleStore()
        let state = PanelState(store: store)
        state.toggleDeleted()
        let entries = store.deletedPriorities.map { DeletedEntry($0) }
        let section = DeletedSection(entries: entries, confirmingAtStart: entries.first?.id)
            .environment(store)
            .environment(state)
            .panelChrome()
        try expectPNG(section, named: "deleted-section-confirm")
        try expectPNG(
            DoneRow(title: entries[0].title, kind: .deleted, isHoveringAtStart: true, doneTime: "09:40").panelChrome(),
            named: "deleted-row-hover"
        )
    }

    @Test
    func rendersTheWindowSectionAndTheReadOnlyDetail() throws {
        let store = try sampleStore()
        let state = PanelState(store: store)
        state.toggleDone()
        state.toggleDeleted()
        try expectPNG(window(store, state), named: "deleted-section-window-980")
        state.openDetail(try deletedID(store, "Pagar el hosting"))
        try expectPNG(window(store, state), named: "deleted-detail-window-980")
        try expectPNG(panel(store, state), named: "deleted-detail-panel")
    }

    @Test
    func rendersTheNotesSectionAndTheReadOnlyNote() async throws {
        let store = try sampleStore()
        let state = PanelState(store: store)
        state.select(tab: .notes)
        state.toggleDeleted()
        try expectPNG(panel(store, state), named: "deleted-notes-panel-open")
        state.openNote(try #require(store.deletedNotes.first).id)
        let harness = RichNoteHarness(window(store, state), size: NSSize(width: 980, height: 680))
        defer { harness.close() }
        await RichNoteHarness.settle(400)
        let url = try harness.screenshot(named: "deleted-note-detail-window-980")
        #expect(try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) > 0)
    }
}
