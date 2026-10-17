import Foundation
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct AppStoreNoteAndStateTests {
    let clock = TestClock()

    @Test
    func periodsComeFromTheClock() throws {
        let store = try makeStore(clock)
        #expect(store.period(.day) == "2026-10-12")
        #expect(store.period(.week) == "2026-W42")
        clock.date = localDate("2026-10-19T00:00:00")
        #expect(store.period(.day) == "2026-10-19")
        #expect(store.period(.week) == "2026-W43")
    }

    @Test
    func saveNoteInsertsThenUpdatesOneRow() throws {
        let store = try makeStore(clock)
        #expect(store.noteBody(.day) == "")

        try store.saveNote("Call Ana", scope: .day)
        clock.advance(minutes: 15)
        try store.saveNote("Call Ana at 15:00", scope: .day)

        #expect(store.noteBody(.day) == "Call Ana at 15:00")
        #expect(try values("SELECT body FROM note", in: store.database) == ["Call Ana at 15:00"])
        #expect(try values("SELECT period FROM note", in: store.database) == ["2026-10-12"])
        #expect(try values("SELECT updated_at FROM note", in: store.database) == ["2026-10-12T09:15:00"])
    }

    @Test
    func eachDayAndEachWeekKeepsItsNote() throws {
        let store = try makeStore(clock)
        try store.saveNote("Monday", scope: .day)
        try store.saveNote("Week 42", scope: .week)
        clock.date = localDate("2026-10-13T08:00:00")
        try store.saveNote("Tuesday", scope: .day)

        #expect(store.noteBody(.day) == "Tuesday")
        #expect(store.noteBody(.day, period: "2026-10-12") == "Monday")
        #expect(store.noteBody(.week) == "Week 42")
        #expect(store.noteBody(.week, period: "2026-W43") == "")
        #expect(try values("SELECT COUNT(*) FROM note", in: store.database) == [3])
    }

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
