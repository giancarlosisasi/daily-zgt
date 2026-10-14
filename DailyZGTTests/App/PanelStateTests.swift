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
        #expect(state.scope == .today)
    }

    @Test
    func tabAndScopeAreSavedInAppState() throws {
        let store = try makeStore()
        let state = PanelState(store: store)
        state.select(tab: .notes)
        state.select(scope: .week)
        #expect(try values("SELECT value FROM app_state WHERE key = 'open_tab'", in: store.database) == ["\"notes\""])
        #expect(try values("SELECT value FROM app_state WHERE key = 'open_scope'", in: store.database) == ["\"week\""])
        #expect(state.saveError == nil)
    }

    @Test
    func aNewStoreOnTheSameDatabaseRestoresTheTabAndTheScope() throws {
        let database = try AppDatabase.inMemory()
        let first = PanelState(store: AppStore(database: database))
        first.select(tab: .notes)
        first.select(scope: .week)

        let second = PanelState(store: AppStore(database: database))
        #expect(second.tab == .notes)
        #expect(second.scope == .week)
    }

    @Test
    func theValuesSurviveAFileReopen() throws {
        let url = try temporaryFolder("panel-state").appending(path: "daily-zgt.sqlite")
        let first = PanelState(store: AppStore(database: try AppDatabase.onDisk(at: url)))
        first.select(tab: .notes)
        first.select(scope: .week)

        let second = PanelState(store: AppStore(database: try AppDatabase.onDisk(at: url)))
        #expect(second.tab == .notes)
        #expect(second.scope == .week)
    }

    @Test
    func selectingTheSameValueWritesNothing() throws {
        let store = try makeStore()
        let state = PanelState(store: store)
        state.select(tab: .priorities)
        state.select(scope: .today)
        #expect(try values("SELECT key FROM app_state", in: store.database, as: String.self).isEmpty)
    }

    @Test
    func theScopeMapsToTheNoteScope() {
        #expect(PriorityList.today.noteScope == .day)
        #expect(PriorityList.week.noteScope == .week)
    }
}
