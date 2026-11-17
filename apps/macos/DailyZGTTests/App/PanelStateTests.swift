import Foundation
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct PanelStateTests {
    @Test
    func startsOnPrioritiesAndToday() throws {
        let state = PanelState(store: try makeStore())
        #expect(state.tab == .priorities)
        #expect(state.filter == .today)
        #expect(state.noteFilter == .today)
    }

    @Test
    func tabFilterAndNoteFilterAreSavedInAppState() throws {
        let store = try makeStore()
        let state = PanelState(store: store)
        state.select(tab: .notes)
        state.select(filter: .week)
        state.select(noteFilter: .week)
        #expect(try values("SELECT value FROM app_state WHERE key = 'open_tab'", in: store.database) == ["\"notes\""])
        #expect(try values("SELECT value FROM app_state WHERE key = 'due_filter'", in: store.database) == ["{\"week\":{}}"])
        #expect(try values("SELECT value FROM app_state WHERE key = 'note_filter'", in: store.database) == ["{\"week\":{}}"])
        #expect(state.saveError == nil)
    }

    @Test
    func aNewStoreOnTheSameDatabaseRestoresTheTabTheFilterAndTheNoteFilter() throws {
        let database = try AppDatabase.inMemory()
        let first = PanelState(store: AppStore(database: database))
        first.select(tab: .notes)
        first.select(filter: .range("2026-11-17", "2026-11-24"))
        first.select(noteFilter: .all)

        let second = PanelState(store: AppStore(database: database))
        #expect(second.tab == .notes)
        #expect(second.filter == .range("2026-11-17", "2026-11-24"))
        #expect(second.noteFilter == .all)
    }

    @Test
    func theValuesSurviveAFileReopen() throws {
        let url = try temporaryFolder("panel-state").appending(path: "daily-zgt.sqlite")
        let first = PanelState(store: AppStore(database: try AppDatabase.onDisk(at: url)))
        first.select(tab: .notes)
        first.select(filter: .overdue)

        let second = PanelState(store: AppStore(database: try AppDatabase.onDisk(at: url)))
        #expect(second.tab == .notes)
        #expect(second.filter == .overdue)
    }

    @Test
    func theOldScopeKeyGivesTheFirstFilterAndNoteFilter() throws {
        let database = try AppDatabase.inMemory()
        try execute("INSERT INTO app_state (key, value) VALUES ('open_scope', '\"week\"')", in: database)
        let state = PanelState(store: AppStore(database: database))
        #expect(state.filter == .week)
        #expect(state.noteFilter == .week)
    }

    @Test
    func aFilterThatDoesNotReadGivesToday() throws {
        let database = try AppDatabase.inMemory()
        try execute("INSERT INTO app_state (key, value) VALUES ('due_filter', 'not json')", in: database)
        try execute("INSERT INTO app_state (key, value) VALUES ('open_scope', '42')", in: database)
        let state = PanelState(store: AppStore(database: database))
        #expect(state.filter == .today)
        #expect(state.noteFilter == .today)
    }

    @Test
    func selectingTheSameValueWritesNothing() throws {
        let store = try makeStore()
        let state = PanelState(store: store)
        state.select(tab: .priorities)
        state.select(filter: .today)
        state.select(filter: .day("2026-10-12"))
        state.select(noteFilter: .today)
        #expect(try values("SELECT key FROM app_state", in: store.database, as: String.self).isEmpty)
    }

    @Test
    func theDayStepMovesTheFilterOneDay() throws {
        let state = PanelState(store: try makeStore())
        state.step(by: 1)
        #expect(state.filter == .tomorrow)
        state.step(by: 1)
        #expect(state.filter == .day("2026-10-14"))
        state.step(by: -2)
        #expect(state.filter == .today)
        state.step(by: -1)
        #expect(state.filter == .day("2026-10-11"))
        state.select(filter: .week)
        state.step(by: 1)
        #expect(state.filter == .week)
    }

    @Test
    func openingAPriorityOutsideTheFilterShowsItsDay() throws {
        let store = try makeStore()
        let later = try store.addPriority(title: "Later", dueAt: localDate("2026-10-20T10:00:00"))
        let today = try store.addPriority(title: "Today")
        let state = PanelState(store: store)
        state.select(filter: .overdue)
        state.openDetail(later.id)
        #expect(state.filter == .day("2026-10-20"))
        state.select(filter: .all)
        state.openDetail(today.id)
        #expect(state.filter == .all)
    }

    @Test
    func theOldNoteScopeGivesTheFirstNoteFilterOnce() throws {
        let database = try AppDatabase.inMemory()
        try execute("INSERT INTO app_state (key, value) VALUES ('note_scope', '\"week\"')", in: database)
        let first = PanelState(store: AppStore(database: database))
        #expect(first.noteFilter == .week)
        first.select(noteFilter: .today)
        let second = PanelState(store: AppStore(database: database))
        #expect(second.noteFilter == .today)
    }

    @Test
    func theNoteDayStepStopsAtToday() throws {
        let state = PanelState(store: try makeStore())
        state.stepNotes(by: 1)
        #expect(state.noteFilter == .today)
        state.stepNotes(by: -1)
        #expect(state.noteFilter == .day("2026-10-11"))
        state.stepNotes(by: 1)
        #expect(state.noteFilter == .today)
    }

    @Test
    func aNewNoteOpensWithFocusAndSwitchesToTodayWhenTheFilterIsAPastDay() throws {
        let store = try makeStore()
        let state = PanelState(store: store)
        state.select(noteFilter: .day("2026-10-01"))
        state.createNote()
        let note = try #require(state.detailNote)
        #expect(state.tab == .notes)
        #expect(state.noteFilter == .today)
        #expect(state.openNoteID == note.id)
        #expect(state.focusNoteID == note.id)
        #expect(store.notes(in: .today).map(\.id) == [note.id])
    }

    @Test
    func aNewNoteUnderTheWeekKeepsTheWeek() throws {
        let state = PanelState(store: try makeStore())
        state.select(noteFilter: .week)
        state.createNote()
        #expect(state.noteFilter == .week)
        #expect(state.detailNote != nil)
    }

    @Test
    func openingAnotherNoteDropsTheFocusAndATabChangeClosesTheNote() throws {
        let store = try makeStore()
        let saved = try store.addNote(body: "Guardada")
        let state = PanelState(store: store)
        state.createNote()
        state.openNote(saved.id)
        #expect(state.openNoteID == saved.id)
        #expect(state.focusNoteID == nil)
        state.select(tab: .priorities)
        #expect(state.openNoteID == nil)
    }

    @Test
    func deletingTheOpenNoteClosesItAndUndoBringsItBack() throws {
        let store = try makeStore()
        let recorder = ScheduleRecorder()
        let state = PanelState(store: store, noteFlow: NoteFlow(store: store, schedule: recorder.schedule))
        let note = try store.addNote(body: "# Plan\nTexto")
        state.openNote(note.id)
        state.deleteNote(note.id)
        #expect(state.openNoteID == nil)
        #expect(store.note(id: note.id) == nil)
        #expect(state.noteFlow.undo?.title == "Plan")
        state.noteFlow.undoDelete()
        #expect(store.note(id: note.id) == note)
        #expect(state.noteFlow.undo == nil)
    }

    @Test
    func theUndoOfADeletedNoteEndsAfterItsTime() throws {
        let store = try makeStore()
        let recorder = ScheduleRecorder()
        let state = PanelState(store: store, noteFlow: NoteFlow(store: store, schedule: recorder.schedule))
        let note = try store.addNote(body: "Texto")
        state.deleteNote(note.id)
        #expect(recorder.entries.map(\.delay) == [.milliseconds(5000)])
        recorder.fire(0)
        #expect(state.noteFlow.undo == nil)
    }

    @Test
    func anEmptyNoteHasNoUndo() throws {
        let store = try makeStore()
        let state = PanelState(store: store)
        let note = try store.addNote(body: "  ")
        state.deleteNote(note.id)
        #expect(state.noteFlow.undo == nil)
    }
}
