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
        #expect(state.noteScope == .day)
    }

    @Test
    func tabFilterAndNoteScopeAreSavedInAppState() throws {
        let store = try makeStore()
        let state = PanelState(store: store)
        state.select(tab: .notes)
        state.select(filter: .week)
        state.select(noteScope: .week)
        #expect(try values("SELECT value FROM app_state WHERE key = 'open_tab'", in: store.database) == ["\"notes\""])
        #expect(try values("SELECT value FROM app_state WHERE key = 'due_filter'", in: store.database) == ["{\"week\":{}}"])
        #expect(try values("SELECT value FROM app_state WHERE key = 'note_scope'", in: store.database) == ["\"week\""])
        #expect(state.saveError == nil)
    }

    @Test
    func aNewStoreOnTheSameDatabaseRestoresTheTabTheFilterAndTheNoteScope() throws {
        let database = try AppDatabase.inMemory()
        let first = PanelState(store: AppStore(database: database))
        first.select(tab: .notes)
        first.select(filter: .range("2026-11-17", "2026-11-24"))
        first.select(noteScope: .week)

        let second = PanelState(store: AppStore(database: database))
        #expect(second.tab == .notes)
        #expect(second.filter == .range("2026-11-17", "2026-11-24"))
        #expect(second.noteScope == .week)
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
    func theOldScopeKeyGivesTheFirstFilterAndNoteScope() throws {
        let database = try AppDatabase.inMemory()
        try execute("INSERT INTO app_state (key, value) VALUES ('open_scope', '\"week\"')", in: database)
        let state = PanelState(store: AppStore(database: database))
        #expect(state.filter == .week)
        #expect(state.noteScope == .week)
    }

    @Test
    func aFilterThatDoesNotReadGivesToday() throws {
        let database = try AppDatabase.inMemory()
        try execute("INSERT INTO app_state (key, value) VALUES ('due_filter', 'not json')", in: database)
        try execute("INSERT INTO app_state (key, value) VALUES ('open_scope', '42')", in: database)
        let state = PanelState(store: AppStore(database: database))
        #expect(state.filter == .today)
        #expect(state.noteScope == .day)
    }

    @Test
    func selectingTheSameValueWritesNothing() throws {
        let store = try makeStore()
        let state = PanelState(store: store)
        state.select(tab: .priorities)
        state.select(filter: .today)
        state.select(filter: .day("2026-10-12"))
        state.select(noteScope: .day)
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
}
