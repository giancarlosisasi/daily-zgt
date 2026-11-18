import Foundation
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct PanelStateTests {
    @Test
    func startsOnPrioritiesAndAll() throws {
        let state = PanelState(store: try makeStore())
        #expect(state.tab == .priorities)
        #expect(state.filter == .all)
        #expect(state.noteFilter == .all)
    }

    @Test
    func theTabIsSavedInAppStateAndTheFiltersAreNot() throws {
        let store = try makeStore()
        let state = PanelState(store: store)
        state.select(tab: .notes)
        state.select(filter: .week)
        state.select(noteFilter: .week)
        #expect(try values("SELECT key FROM app_state", in: store.database, as: String.self) == ["open_tab"])
        #expect(try values("SELECT value FROM app_state WHERE key = 'open_tab'", in: store.database) == ["\"notes\""])
        #expect(state.saveError == nil)
    }

    @Test
    func aNewLaunchRestoresTheTabAndStartsBothFiltersAtAll() throws {
        let database = try AppDatabase.inMemory()
        let first = PanelState(store: AppStore(database: database))
        first.select(tab: .notes)
        first.select(filter: .range("2026-11-17", "2026-11-24"))
        first.select(noteFilter: .today)

        let second = PanelState(store: AppStore(database: database))
        #expect(second.tab == .notes)
        #expect(second.filter == .all)
        #expect(second.noteFilter == .all)
    }

    @Test
    func aFileReopenKeepsTheTabAndStartsTheFilterAtAll() throws {
        let url = try temporaryFolder("panel-state").appending(path: "daily-zgt.sqlite")
        let first = PanelState(store: AppStore(database: try AppDatabase.onDisk(at: url)))
        first.select(tab: .notes)
        first.select(filter: .overdue)

        let second = PanelState(store: AppStore(database: try AppDatabase.onDisk(at: url)))
        #expect(second.tab == .notes)
        #expect(second.filter == .all)
    }

    @Test
    func oldSavedFilterAndScopeKeysDoNotChangeTheFirstFilter() throws {
        let database = try AppDatabase.inMemory()
        try execute("INSERT INTO app_state (key, value) VALUES ('open_scope', '\"today\"')", in: database)
        try execute("INSERT INTO app_state (key, value) VALUES ('note_scope', '\"week\"')", in: database)
        try execute("INSERT INTO app_state (key, value) VALUES ('due_filter', '{\"today\":{}}')", in: database)
        try execute("INSERT INTO app_state (key, value) VALUES ('note_filter', 'not json')", in: database)
        let state = PanelState(store: AppStore(database: database))
        #expect(state.filter == .all)
        #expect(state.noteFilter == .all)
        #expect(try values("SELECT key FROM app_state ORDER BY key", in: database, as: String.self) == ["due_filter", "note_filter", "note_scope", "open_scope"])
    }

    @Test
    func theFilterChoiceStaysInsideOneRun() throws {
        let state = PanelState(store: try makeStore())
        state.select(filter: .week)
        state.select(noteFilter: .today)
        state.select(tab: .notes)
        state.openSettings()
        state.closeSettings()
        state.select(tab: .priorities)
        #expect(state.filter == .week)
        #expect(state.noteFilter == .today)
    }

    @Test
    func selectingTheSameValueWritesNothing() throws {
        let store = try makeStore()
        let state = PanelState(store: store)
        state.select(tab: .priorities)
        state.select(filter: .all)
        state.select(noteFilter: .all)
        #expect(try values("SELECT key FROM app_state", in: store.database, as: String.self).isEmpty)
    }

    @Test
    func aCalendarPickOfTomorrowKeepsThatDateOnTheNextDay() throws {
        let clock = TestClock("2026-10-12T09:00:00")
        let store = AppStore(database: try AppDatabase.inMemory(), now: { clock.date })
        let state = PanelState(store: store)
        state.select(filter: DueFilter.picked(day: localDate("2026-10-13T00:00:00"), store.dueDays))
        state.select(noteFilter: DueFilter.picked(day: localDate("2026-10-13T00:00:00"), store.dueDays))
        #expect(state.filter == .day("2026-10-13"))
        clock.advance(minutes: 24 * 60)
        #expect(state.filter == .day("2026-10-13"))
        #expect(state.noteFilter == .day("2026-10-13"))
        #expect(state.filter.resolved(store.dueDays) == .today)
    }

    @Test
    func theDayStepMovesTheFilterOneDay() throws {
        let state = PanelState(store: try makeStore())
        state.step(by: 1)
        #expect(state.filter == .all)
        state.select(filter: .today)
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
    func theNoteDayStepStopsAtToday() throws {
        let state = PanelState(store: try makeStore())
        state.stepNotes(by: 1)
        #expect(state.noteFilter == .all)
        state.select(noteFilter: .today)
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
    func deletingTheOpenNoteFromItsRowKeepsTheTextTypedJustBefore() throws {
        let store = try makeStore()
        let recorder = ScheduleRecorder()
        let state = PanelState(store: store, noteFlow: NoteFlow(store: store, schedule: recorder.schedule))
        let note = try store.addNote(body: "Plan")
        state.openNote(note.id)
        let model = NoteBodyModel(store: store, noteID: note.id, schedule: recorder.schedule)
        state.registerNoteFlush(note.id) { model.flush() }
        model.edit("Plan con detalle")
        state.deleteNote(note.id)
        #expect(state.noteFlow.undo?.note.body == "Plan con detalle")
        state.noteFlow.undoDelete()
        #expect(store.note(id: note.id)?.body == "Plan con detalle")
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
