import Foundation
import GRDB
import Testing
@testable import DailyZGT

struct NoteRow: Equatable {
    let scope: String
    let period: String
    let body: String
}

@MainActor
func noteRows(in store: AppStore) throws -> [NoteRow] {
    try store.database.read { database in
        try Row.fetchAll(database, sql: "SELECT scope, period, body FROM note ORDER BY scope, period").map {
            NoteRow(scope: $0["scope"], period: $0["period"], body: $0["body"])
        }
    }
}

@Suite
@MainActor
struct NotesModelTests {
    let clock = TestClock("2026-10-12T09:00:00")
    let recorder = ScheduleRecorder()

    private func makeModel(_ store: AppStore, scope: NoteScope = .day) -> NotesModel {
        NotesModel(store: store, scope: scope, schedule: recorder.schedule)
    }

    @Test
    func theModelStartsWithThePeriodOfTheStoreClock() throws {
        let store = try makeStore(clock)
        #expect(makeModel(store).period == "2026-10-12")
        #expect(makeModel(store, scope: .week).period == "2026-W42")
    }

    @Test
    func theModelStartsWithTheSavedBody() throws {
        let store = try makeStore(clock)
        try store.saveNote("Saved", scope: .day)
        #expect(makeModel(store).text == "Saved")
    }

    @Test
    func typingThenWaitingSavesOnce() throws {
        let store = try makeStore(clock)
        let model = makeModel(store)

        model.edit("Hola")
        #expect(recorder.entries.map(\.delay) == [.milliseconds(400)])
        #expect(try noteRows(in: store) == [])
        #expect(model.hasUnsavedEdit)

        recorder.fire(0)
        #expect(try noteRows(in: store) == [NoteRow(scope: "day", period: "2026-10-12", body: "Hola")])
        #expect(!model.hasUnsavedEdit)
        #expect(!model.writeFailed)
    }

    @Test
    func twoFastEditsSaveOnce() throws {
        let store = try makeStore(clock)
        let model = makeModel(store)

        model.edit("H")
        model.edit("Ho")
        recorder.fire(0)
        #expect(try noteRows(in: store) == [])
        #expect(model.hasUnsavedEdit)

        recorder.fire(1)
        #expect(try noteRows(in: store) == [NoteRow(scope: "day", period: "2026-10-12", body: "Ho")])
    }

    @Test
    func aTimerAfterAFlushWritesNothingMore() throws {
        let store = try makeStore(clock)
        let model = makeModel(store)
        model.edit("First")
        model.flush()
        clock.advance(minutes: 5)
        model.edit("Second")
        model.flush()
        recorder.fire(0)
        recorder.fire(1)

        #expect(try noteRows(in: store).map(\.body) == ["Second"])
        let stamps = try values("SELECT updated_at FROM note", in: store.database, as: String.self)
        #expect(stamps == ["2026-10-12T09:05:00"])
    }

    @Test
    func aFlushSavesAtOnceWithoutWaitingForTheTimer() throws {
        let store = try makeStore(clock)
        let model = makeModel(store)

        model.edit("Closing the panel")
        model.flush()

        #expect(store.noteBody(.day) == "Closing the panel")
        #expect(!model.hasUnsavedEdit)
    }

    @Test
    func aFlushWithNoEditWritesNothing() throws {
        let store = try makeStore(clock)
        let model = makeModel(store)
        model.flush()
        #expect(try noteRows(in: store) == [])
    }

    @Test
    func aScopeChangeSavesTheOldScopeFirst() throws {
        let store = try makeStore(clock)
        let model = makeModel(store)
        try store.saveNote("Week text", scope: .week)

        model.edit("Day text")
        model.select(scope: .week)

        #expect(store.noteBody(.day) == "Day text")
        #expect(model.scope == .week)
        #expect(model.period == "2026-W42")
        #expect(model.text == "Week text")
        #expect(!model.hasUnsavedEdit)

        recorder.fire(0)
        #expect(store.noteBody(.week) == "Week text")
    }

    @Test
    func theDayNoteAndTheWeekNoteAreSeparateRows() throws {
        let store = try makeStore(clock)
        let model = makeModel(store)

        model.edit("Day")
        model.select(scope: .week)
        model.edit("Week")
        model.flush()

        #expect(try noteRows(in: store) == [
            NoteRow(scope: "day", period: "2026-10-12", body: "Day"),
            NoteRow(scope: "week", period: "2026-W42", body: "Week"),
        ])
        model.select(scope: .day)
        #expect(model.text == "Day")
    }

    @Test
    func aNewDayReadsAnotherRowAndTheOldTextIsAlreadySaved() throws {
        let store = try makeStore(clock)
        try store.saveNote("Tomorrow plan", scope: .day, period: "2026-10-13")
        let model = makeModel(store)
        model.edit("Monday text")

        clock.advance(minutes: 24 * 60)
        model.sync()

        #expect(try noteRows(in: store).map(\.body) == ["Monday text", "Tomorrow plan"])
        #expect(model.period == "2026-10-13")
        #expect(model.text == "Tomorrow plan")
        #expect(!model.hasUnsavedEdit)

        recorder.fire(0)
        #expect(store.noteBody(.day, period: "2026-10-12") == "Monday text")
        #expect(store.noteBody(.day, period: "2026-10-13") == "Tomorrow plan")
    }

    @Test
    func aNewWeekShowsAnEmptyNote() throws {
        let store = try makeStore(clock)
        let model = makeModel(store, scope: .week)
        model.edit("Week 42")

        clock.advance(minutes: 7 * 24 * 60)
        model.sync()

        #expect(model.period == "2026-W43")
        #expect(model.text == "")
        #expect(store.noteBody(.week, period: "2026-W42") == "Week 42")
    }

    @Test
    func syncInTheSamePeriodKeepsTheText() throws {
        let store = try makeStore(clock)
        let model = makeModel(store)
        model.edit("Typing")
        model.sync()
        #expect(model.text == "Typing")
        #expect(model.hasUnsavedEdit)
    }

    @Test(.timeLimit(.minutes(1)))
    func anExternalChangeShowsWhenThePersonIsNotEditing() async throws {
        let store = try makeStore(clock)
        let model = makeModel(store)

        try await nextChange(of: store) {
            try execute(
                """
                INSERT INTO note (scope, period, body, updated_at)
                VALUES ('day', '2026-10-12', 'From sqlite3', '2026-10-12T09:01:00')
                """,
                in: store.database
            )
        }
        model.sync()

        #expect(model.text == "From sqlite3")
        #expect(model.externalBody == "From sqlite3")
        #expect(!model.hasUnsavedEdit)
    }

    @Test(.timeLimit(.minutes(1)))
    func anExternalChangeWaitsWhileThePersonIsEditing() async throws {
        let store = try makeStore(clock)
        let model = makeModel(store)
        model.edit("My draft")

        try await nextChange(of: store) {
            try execute(
                """
                INSERT INTO note (scope, period, body, updated_at)
                VALUES ('day', '2026-10-12', 'From sqlite3', '2026-10-12T09:01:00')
                """,
                in: store.database
            )
        }
        model.sync()
        #expect(model.text == "My draft")

        model.flush()
        #expect(store.noteBody(.day) == "My draft")
    }

    @Test
    func anEmptyTextSavesAsAnEmptyBodyAndTheRowStays() throws {
        let store = try makeStore(clock)
        try store.saveNote("Something", scope: .day)
        let model = makeModel(store)

        model.edit("")
        model.flush()

        #expect(try noteRows(in: store) == [NoteRow(scope: "day", period: "2026-10-12", body: "")])
    }

    @Test
    func anEmptyTextOnANoteWithNoRowWritesNothing() throws {
        let store = try makeStore(clock)
        let model = makeModel(store)

        model.edit("x")
        model.edit("")
        model.flush()

        #expect(try noteRows(in: store) == [])
    }

    @Test
    func aFailedWriteKeepsTheEditAndRaisesTheFlag() throws {
        let store = try makeStore(clock)
        let model = makeModel(store)
        try execute("DROP TABLE note", in: store.database)

        model.edit("Lost?")
        model.flush()

        #expect(model.writeFailed)
        #expect(model.hasUnsavedEdit)
        #expect(model.text == "Lost?")
    }
}
