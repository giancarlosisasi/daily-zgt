import Foundation
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct CaptureModelTests {
    let clock = TestClock("2026-10-12T10:24:00")

    private func limited(_ store: AppStore, open: Int) throws {
        PanelState(store: store).setTodayLimit(true)
        for index in 0..<open {
            try store.addPriority(title: "Open \(index)", list: .today)
        }
    }

    @Test
    func startsEmptyWithNoNotice() throws {
        let model = CaptureModel(store: try makeStore(clock))
        #expect(model.draft.title.isEmpty)
        #expect(model.notice == nil)
        #expect(model.limitMessage == nil)
    }

    @Test
    func anEmptyTitleAddsNothing() throws {
        let store = try makeStore(clock)
        let model = CaptureModel(store: store)
        #expect(!model.submit())
        #expect(store.openCount(in: .today) == 0)
    }

    @Test
    func aTitleOfSpacesAddsNothingAndKeepsTheText() throws {
        let store = try makeStore(clock)
        let model = CaptureModel(store: store)
        model.draft.title = "  \n "
        #expect(!model.submit())
        #expect(model.draft.title == "  \n ")
        #expect(store.openCount(in: .today) == 0)
        #expect(model.notice == nil)
    }

    @Test
    func aTitleIsTrimmedAndAddedToHoyWithMediaAndNoDue() throws {
        let store = try makeStore(clock)
        let model = CaptureModel(store: store)
        model.draft.title = "  Pagar la luz  "
        #expect(model.submit())

        let added = try #require(store.openPriorities(in: .today).first)
        #expect(added.title == "Pagar la luz")
        #expect(added.level == .medium)
        #expect(added.list == .today)
        #expect(added.dueAt == nil)
        #expect(added.note.isEmpty)
        #expect(!added.isDone)
        #expect(store.openCount(in: .week) == 0)
    }

    @Test
    func theAddWritesTheCreatedEvent() throws {
        let store = try makeStore(clock)
        let model = CaptureModel(store: store)
        model.draft.title = "Pagar la luz"
        model.submit()

        let added = try #require(store.openPriorities(in: .today).first)
        #expect(try store.events(of: added.id).map(\.type) == [.created])
    }

    @Test
    func theAddCreatesNoAlert() throws {
        let store = try makeStore(clock)
        let model = CaptureModel(store: store)
        model.draft.title = "Pagar la luz"
        model.submit()
        #expect(try store.alerts().isEmpty)
    }

    @Test
    func aSuccessfulAddClearsTheDraft() throws {
        let model = CaptureModel(store: try makeStore(clock))
        model.draft.title = "Pagar la luz"
        model.submit()
        #expect(model.draft.title.isEmpty)
        #expect(model.notice == nil)
    }

    @Test
    func theAddedRowShowsInTheMenuBarCountAndTitle() throws {
        let store = try makeStore(clock)
        let state = PanelState(store: store)
        let capture = CaptureController(store: store)
        let boot = AppBoot.ready(store, state, AlertCoordinator(store: store, center: InertNotificationCenter()), capture)
        #expect(boot.menuBarCount == 0)
        #expect(boot.menuBarTitle == nil)

        capture.model.draft.title = "Pagar la luz"
        capture.model.submit()

        #expect(boot.menuBarCount == 1)
        #expect(boot.menuBarTitle == "Pagar la luz")
        #expect(store.openCount(in: .today) == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func theAddWakesTheStoreObservers() async throws {
        let store = try makeStore(clock)
        let model = CaptureModel(store: store)
        model.draft.title = "Observed"
        try await nextChange(of: store) { model.submit() }
        #expect(store.openPriorities(in: .today).map(\.title) == ["Observed"])
    }

    @Test
    func withTheLimitOnAndFiveOpenTheAddIsBlockedAndTheTextStays() throws {
        let store = try makeStore(clock)
        try limited(store, open: TodayLimit.maxOpen)
        let model = CaptureModel(store: store)
        model.draft.title = "Una más"

        #expect(!model.submit())

        #expect(model.limitMessage == "Hoy ya tiene 5 prioridades abiertas.")
        #expect(model.notice == TodayLimit.message)
        #expect(model.draft.title == "Una más")
        #expect(store.openCount(in: .today) == TodayLimit.maxOpen)
        #expect(try values("SELECT COUNT(*) FROM priority", in: store.database) == [TodayLimit.maxOpen])
    }

    @Test
    func theBlockedAddWritesNoEvent() throws {
        let store = try makeStore(clock)
        try limited(store, open: TodayLimit.maxOpen)
        let before = try values("SELECT COUNT(*) FROM priority_event", in: store.database, as: Int.self)
        let model = CaptureModel(store: store)
        model.draft.title = "Una más"
        model.submit()
        #expect(try values("SELECT COUNT(*) FROM priority_event", in: store.database, as: Int.self) == before)
    }

    @Test
    func withTheLimitOnAndFourOpenTheAddWorks() throws {
        let store = try makeStore(clock)
        try limited(store, open: TodayLimit.maxOpen - 1)
        let model = CaptureModel(store: store)
        model.draft.title = "La quinta"
        #expect(model.submit())
        #expect(store.openCount(in: .today) == TodayLimit.maxOpen)
    }

    @Test
    func withTheLimitOffTheAddWorksWithManyOpen() throws {
        let store = try makeStore(clock)
        for index in 0..<7 {
            try store.addPriority(title: "Open \(index)", list: .today)
        }
        let model = CaptureModel(store: store)
        model.draft.title = "La octava"
        #expect(model.submit())
        #expect(store.openCount(in: .today) == 8)
    }

    @Test
    func theLimitLineGoesAwayAfterTheAddWorks() throws {
        let store = try makeStore(clock)
        try limited(store, open: TodayLimit.maxOpen)
        let model = CaptureModel(store: store)
        model.draft.title = "Una más"
        model.submit()
        #expect(model.notice != nil)

        let first = try #require(store.openPriorities(in: .today).first)
        try store.markDone(first.id)
        #expect(model.submit())
        #expect(model.notice == nil)
        #expect(model.draft.title.isEmpty)
    }

    @Test
    func aResetClearsTheTextAndTheLimitLine() throws {
        let store = try makeStore(clock)
        try limited(store, open: TodayLimit.maxOpen)
        let model = CaptureModel(store: store)
        model.draft.title = "Una más"
        model.submit()
        model.reset()
        #expect(model.draft.title.isEmpty)
        #expect(model.notice == nil)
    }

    @Test
    func aFailedWriteKeepsTheTextAndShowsTheSaveLine() throws {
        let store = try makeStore(clock)
        try execute("DROP TABLE priority_event", in: store.database)
        let model = CaptureModel(store: store)
        model.draft.title = "Pagar la luz"

        #expect(!model.submit())

        #expect(model.saveFailed)
        #expect(model.notice == CaptureCopy.saveFailed)
        #expect(model.draft.title == "Pagar la luz")
        #expect(store.openCount(in: .today) == 0)
    }

    @Test
    func aFocusRequestChangesTheCounter() throws {
        let model = CaptureModel(store: try makeStore(clock))
        let before = model.focusRequests
        model.requestFocus()
        #expect(model.focusRequests == before + 1)
    }

    @Test
    func theCopyIsTheCopyOfTheTeclaWindow() {
        #expect(CaptureCopy.title == "Nueva prioridad")
        #expect(CaptureCopy.placeholder == "¿Qué es prioritario?")
        #expect(CaptureCopy.hint == "Enter agrega. Escape cierra.")
    }
}
