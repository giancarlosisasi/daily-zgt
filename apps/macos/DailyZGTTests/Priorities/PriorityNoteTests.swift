import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct PriorityNoteRuleTests {
    @Test
    func anEmptyOrBlankNoteStoresAsEmpty() {
        #expect(PriorityNote.stored(from: "") == "")
        #expect(PriorityNote.stored(from: "   ") == "")
        #expect(PriorityNote.stored(from: "\n\t \n") == "")
    }

    @Test
    func aNoteWithTextKeepsItsText() {
        #expect(PriorityNote.stored(from: " a ") == " a ")
        #expect(PriorityNote.stored(from: "Doc\n\nlink") == "Doc\n\nlink")
    }

    @Test
    func theIconShowsOnlyForANoteWithText() {
        #expect(!PriorityNote.isPresent(""))
        #expect(!PriorityNote.isPresent("  \n "))
        #expect(PriorityNote.isPresent("a"))
        #expect(PriorityNote.isPresent("  a  "))
    }
}

@Suite
@MainActor
struct PriorityNoteModelTests {
    let clock = TestClock("2026-10-12T09:00:00")
    let recorder = ScheduleRecorder()

    private func makeModel(_ store: AppStore, _ priority: Priority) -> PriorityNoteModel {
        PriorityNoteModel(store: store, priorityID: priority.id, schedule: recorder.schedule)
    }

    private func edited(_ store: AppStore, _ id: Priority.ID) throws -> Int {
        try store.events(of: id).filter { $0.type == .edited }.count
    }

    private func note(_ store: AppStore, _ id: Priority.ID) -> String? {
        store.priority(id: id)?.note
    }

    @Test
    func theModelStartsWithTheStoredNote() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "P", list: .today, note: "Doc del brief.")
        #expect(makeModel(store, priority).text == "Doc del brief.")
    }

    @Test
    func typingThenWaitingSavesOnce() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "P", list: .today)
        let model = makeModel(store, priority)

        model.edit("Hola")
        #expect(recorder.entries.map(\.delay) == [.milliseconds(400)])
        #expect(note(store, priority.id) == "")
        #expect(model.hasUnsavedEdit)

        recorder.fire(0)
        #expect(note(store, priority.id) == "Hola")
        #expect(!model.hasUnsavedEdit)
        #expect(!model.writeFailed)
        #expect(try edited(store, priority.id) == 1)
    }

    @Test
    func twoFastEditsSaveOnce() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "P", list: .today)
        let model = makeModel(store, priority)

        model.edit("H")
        model.edit("Ho")
        recorder.fire(0)
        #expect(note(store, priority.id) == "")

        recorder.fire(1)
        #expect(note(store, priority.id) == "Ho")
        #expect(try edited(store, priority.id) == 1)
    }

    @Test
    func aFlushOnCloseSavesAtOnceAndTheTimerWritesNothingMore() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "P", list: .today)
        let model = makeModel(store, priority)

        model.edit("Closing the detail")
        model.flush()
        #expect(note(store, priority.id) == "Closing the detail")
        #expect(!model.hasUnsavedEdit)

        recorder.fire(0)
        #expect(try edited(store, priority.id) == 1)
    }

    @Test
    func aFlushWithNoEditWritesNothing() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "P", list: .today, note: "Same")
        let model = makeModel(store, priority)
        model.flush()
        #expect(try edited(store, priority.id) == 0)
    }

    @Test
    func textThatEqualsTheStoredNoteWritesNothing() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "P", list: .today, note: "Same")
        let model = makeModel(store, priority)

        model.edit("Same!")
        model.edit("Same")
        model.flush()

        #expect(note(store, priority.id) == "Same")
        #expect(!model.hasUnsavedEdit)
        #expect(try edited(store, priority.id) == 0)
    }

    @Test
    func aBlankTextOnAnEmptyNoteWritesNothing() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "P", list: .today)
        let model = makeModel(store, priority)

        model.edit("   \n ")
        model.flush()

        #expect(note(store, priority.id) == "")
        #expect(try edited(store, priority.id) == 0)
        #expect(!PriorityNote.isPresent(note(store, priority.id) ?? ""))
    }

    @Test
    func clearingTheTextWithOnlySpacesStoresAnEmptyNote() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "P", list: .today, note: "Doc")
        let model = makeModel(store, priority)

        model.edit("  \n ")
        model.flush()

        #expect(note(store, priority.id) == "")
        #expect(try edited(store, priority.id) == 1)
        #expect(!PriorityNote.isPresent(note(store, priority.id) ?? ""))
    }

    @Test
    func eachSavedPauseWritesOneEditedEvent() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "P", list: .today)
        let model = makeModel(store, priority)

        model.edit("one")
        model.flush()
        model.edit("one two")
        model.flush()
        model.edit("one two")
        model.flush()

        #expect(try edited(store, priority.id) == 2)
        #expect(try store.events(of: priority.id).map(\.type) == [.created, .edited, .edited])
    }

    @Test
    func aSaveKeepsTheOtherFieldsOfThePriority() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(
            title: "Title",
            level: .high,
            list: .week,
            dueAt: localDate("2026-10-14T10:00:00")
        )
        let model = makeModel(store, priority)
        model.edit("Note")
        model.flush()

        let saved = try #require(store.priority(id: priority.id))
        #expect(saved.title == "Title")
        #expect(saved.level == .high)
        #expect(saved.list == .week)
        #expect(saved.dueAt == priority.dueAt)
        #expect(saved.note == "Note")
    }

    @Test
    func aDeletedPriorityDropsTheEditWithoutAnError() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "P", list: .today)
        let model = makeModel(store, priority)
        model.edit("Lost")
        try store.deletePriority(priority.id)

        model.flush()

        #expect(!model.hasUnsavedEdit)
        #expect(!model.writeFailed)
    }

    @Test(.timeLimit(.minutes(1)))
    func anExternalChangeShowsWhenThePersonIsNotEditing() async throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "P", list: .today)
        let model = makeModel(store, priority)

        try await nextChange(of: store) {
            try execute("UPDATE priority SET note = 'From sqlite3'", in: store.database)
        }
        model.sync()

        #expect(model.text == "From sqlite3")
        #expect(model.externalNote == "From sqlite3")
        #expect(!model.hasUnsavedEdit)
    }

    @Test(.timeLimit(.minutes(1)))
    func anExternalChangeWaitsWhileThePersonIsEditing() async throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "P", list: .today)
        let model = makeModel(store, priority)
        model.edit("My draft")

        try await nextChange(of: store) {
            try execute("UPDATE priority SET note = 'From sqlite3'", in: store.database)
        }
        model.sync()
        #expect(model.text == "My draft")

        model.flush()
        #expect(note(store, priority.id) == "My draft")
    }

    @Test
    func syncKeepsTheSpacesTheNoteStoresAsEmpty() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "P", list: .today)
        let model = makeModel(store, priority)
        model.edit("  ")
        model.flush()
        model.sync()
        #expect(model.text == "  ")
    }
}

@Suite
@MainActor
struct PriorityNoteRenderTests {
    let clock = TestClock("2026-10-12T10:24:00")

    private func render(_ view: some View, named name: String) throws {
        let url = try Screenshot.writeHosted(view, named: name)
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func rendersTheDetailWithANote() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(
            title: "Terminar el brief de Tailwind v4",
            level: .high,
            list: .today,
            dueAt: localDate("2026-10-12T11:00:00"),
            note: "Doc del brief en .gyro/briefs/tailwind-v4.\nFalta decidir si notifications-center entra como piloto."
        )
        try render(
            PriorityDetailView(priority: priority).environment(store).environment(PanelState(store: store)).panelChrome(),
            named: "note-detail-text"
        )
    }

    @Test
    func rendersTheDetailWithThePlaceholder() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "Ordenar el escritorio", level: .low, list: .week)
        try render(
            PriorityDetailView(priority: priority).environment(store).environment(PanelState(store: store)).panelChrome(),
            named: "note-detail-empty"
        )
    }

    @Test
    func rendersRowsWithAndWithoutTheNoteIcon() throws {
        let store = try makeStore(clock)
        try store.addPriority(title: "Con nota", level: .high, list: .today, note: "Contexto")
        try store.addPriority(title: "Sin nota", level: .medium, list: .today)
        try store.addPriority(title: "Nota en blanco", level: .low, list: .today, note: "   ")
        try render(
            PriorityListView(list: .today).environment(store).environment(PanelState(store: store)).panelChrome(),
            named: "note-icon-rows"
        )
    }
}
