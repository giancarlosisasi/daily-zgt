import Foundation
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct AppStoreStateTests {
    let clock = TestClock()

    @Test
    func appStateReturnsTheDefaultThenTheSavedValue() throws {
        let store = try makeStore(clock)
        let tab = AppStateKey(name: "open_tab", defaultValue: "priorities")
        let doneIsOpen = AppStateKey(name: "done_is_open", defaultValue: false)
        let limit = AppStateKey<Int?>(name: "today_limit", defaultValue: nil)

        #expect(store.value(for: tab) == "priorities")
        #expect(store.value(for: doneIsOpen) == false)
        #expect(store.value(for: limit) == nil)

        try store.setValue("notes", for: tab)
        try store.setValue(true, for: doneIsOpen)
        try store.setValue(5, for: limit)
        try store.setValue(false, for: doneIsOpen)

        #expect(store.value(for: tab) == "notes")
        #expect(store.value(for: doneIsOpen) == false)
        #expect(store.value(for: limit) == 5)
        #expect(try values("SELECT value FROM app_state ORDER BY key", in: store.database) == [
            "false", "\"notes\"", "5",
        ])
    }

    @Test(.timeLimit(.minutes(1)))
    func appStateWithUnreadableTextReturnsTheDefault() async throws {
        let store = try makeStore(clock)
        let limit = AppStateKey(name: "today_limit", defaultValue: 5)
        try await nextChange(of: store) {
            try execute("INSERT INTO app_state (key, value) VALUES ('today_limit', 'not json')", in: store.database)
        }
        #expect(store.snapshot.appState["today_limit"] == "not json")
        #expect(store.value(for: limit) == 5)
    }
}
