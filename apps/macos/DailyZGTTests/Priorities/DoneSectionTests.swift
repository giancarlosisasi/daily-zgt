import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct DoneSectionTests {
    let clock = TestClock("2026-10-12T10:24:00")
    let recorder = ScheduleRecorder()

    private func render(_ view: some View, named name: String) throws {
        let url = try Screenshot.writeHosted(view.panelChrome(), named: name)
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    private func list(_ store: AppStore, _ state: PanelState) -> some View {
        PriorityListView(list: .today).environment(store).environment(state)
    }

    private func storeWithDone() throws -> AppStore {
        let store = try makeStore(clock)
        try store.addPriority(title: "Revisar el MR pendiente de compass.ui", level: .high, list: .today, dueAt: localDate("2026-10-12T11:00:00"))
        try store.addPriority(title: "1:1 con el equipo", level: .medium, list: .today)
        for title in ["Enviar la factura", "Pagar el hosting", "Responder a Ana"] {
            let priority = try store.addPriority(title: title, list: .today)
            clock.advance(minutes: 1)
            try store.markDone(priority.id)
        }
        return store
    }

    @Test
    func theSectionIsClosedByDefault() throws {
        let state = PanelState(store: try makeStore(clock))
        #expect(!state.isDoneOpen)
    }

    @Test
    func theStateIsSavedInAppState() throws {
        let store = try makeStore(clock)
        let state = PanelState(store: store)
        state.toggleDone()
        #expect(state.isDoneOpen)
        #expect(try values("SELECT value FROM app_state WHERE key = 'done_open'", in: store.database) == ["true"])
        state.toggleDone()
        #expect(!state.isDoneOpen)
        #expect(try values("SELECT value FROM app_state WHERE key = 'done_open'", in: store.database) == ["false"])
        #expect(state.saveError == nil)
    }

    @Test
    func aNewStateOnTheSameDatabaseRestoresTheSection() throws {
        let database = try AppDatabase.inMemory()
        let first = PanelState(store: AppStore(database: database))
        first.toggleDone()
        let second = PanelState(store: AppStore(database: database))
        #expect(second.isDoneOpen)
    }

    @Test
    func theValueSurvivesAFileReopen() throws {
        let url = try temporaryFolder("done-section").appending(path: "daily-zgt.sqlite")
        let first = PanelState(store: AppStore(database: try AppDatabase.onDisk(at: url)))
        first.toggleDone()
        let second = PanelState(store: AppStore(database: try AppDatabase.onDisk(at: url)))
        #expect(second.isDoneOpen)
    }

    @Test
    func theHeaderShowsTheCountOfTheList() throws {
        let store = try storeWithDone()
        let other = try store.addPriority(title: "Week item", list: .week)
        try store.markDone(other.id)
        #expect(DoneSection.headerTitle(count: store.donePriorities(in: .today).count) == "Hechas (3)")
        #expect(DoneSection.headerTitle(count: store.donePriorities(in: .week).count) == "Hechas (1)")
        #expect(DoneSection.headerTitle(count: 0) == "Hechas (0)")
    }

    @Test
    func theDoneRowsAreTheLatestFirst() throws {
        let store = try storeWithDone()
        #expect(store.donePriorities(in: .today).map(\.title) == ["Responder a Ana", "Pagar el hosting", "Enviar la factura"])
    }

    @Test
    func regresarRestoresThePriorityWritesTheEventAndHighlightsIt() throws {
        let store = try storeWithDone()
        let flow = PriorityFlow(store: store, schedule: recorder.schedule)
        let target = try #require(store.donePriorities(in: .today).first)

        flow.restore(target.id)

        #expect(store.priority(id: target.id)?.isDone == false)
        #expect(store.openPriorities(in: .today).map(\.title).contains("Responder a Ana"))
        #expect(store.donePriorities(in: .today).count == 2)
        #expect(try store.events(of: target.id).map(\.type) == [.created, .done, .restored])
        #expect(flow.highlightedID == target.id)
        #expect(recorder.entries.map(\.delay) == [.milliseconds(1400)])
        recorder.fire(0)
        #expect(flow.highlightedID == nil)
    }

    @Test
    func removingADoneRowDeletesIt() throws {
        let store = try storeWithDone()
        let flow = PriorityFlow(store: store, schedule: recorder.schedule)
        let target = try #require(store.donePriorities(in: .today).first)

        flow.delete(target.id)

        #expect(store.priority(id: target.id) == nil)
        #expect(store.donePriorities(in: .today).count == 2)
        #expect(!flow.writeFailed)
    }

    @Test
    func rendersTheClosedSection() throws {
        let store = try storeWithDone()
        try render(list(store, PanelState(store: store)), named: "done-section-closed")
    }

    @Test
    func rendersTheOpenSection() throws {
        let store = try storeWithDone()
        let state = PanelState(store: store)
        state.toggleDone()
        try render(list(store, state), named: "done-section-open")
    }

    @Test
    func rendersTheOpenSectionWhenEveryPriorityIsDone() throws {
        let store = try makeStore(clock)
        let only = try store.addPriority(title: "Enviar la factura", list: .today)
        try store.markDone(only.id)
        let state = PanelState(store: store)
        state.toggleDone()
        try render(list(store, state), named: "done-section-all-done")
    }

    @Test
    func rendersAHoveredDoneRowWithRegresar() throws {
        let store = try storeWithDone()
        let priority = try #require(store.donePriorities(in: .today).first)
        try render(DoneRow(priority: priority, isHoveringAtStart: true), named: "done-row-hover")
    }

    @Test
    func rendersTheRestoredRowWithTheHighlight() throws {
        let store = try storeWithDone()
        let flow = PriorityFlow(store: store, schedule: recorder.schedule)
        let state = PanelState(store: store, priorityFlow: flow)
        state.toggleDone()
        let target = try #require(store.donePriorities(in: .today).first)
        flow.restore(target.id)
        try render(list(store, state), named: "done-section-restored")
    }
}
