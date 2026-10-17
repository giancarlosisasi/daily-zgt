import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct PriorityDetailViewTests {
    let clock = TestClock("2026-10-09T17:20:00")

    private func sample() throws -> (AppStore, PanelState, Priority) {
        let store = try makeStore(clock)
        let brief = try store.addPriority(
            title: "Terminar el brief de Tailwind v4",
            level: .high,
            list: .today,
            dueAt: localDate("2026-10-12T11:00:00"),
            note: "Doc del brief."
        )
        let first = try store.addSubtask(to: brief.id, title: "Listar las apps piloto")
        try store.addSubtask(to: brief.id, title: "Escribir los criterios")
        try store.toggleSubtask(first.id)
        clock.date = localDate("2026-10-12T10:24:00")
        return (store, PanelState(store: store), brief)
    }

    private func render(_ view: some View, store: AppStore, state: PanelState, named name: String) throws {
        let url = try Screenshot.writeHosted(view.environment(store).environment(state).panelChrome(), named: name)
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func rendersTheDetailOfAPriorityWithADue() throws {
        let (store, state, brief) = try sample()
        try render(PriorityDetailView(priority: brief), store: store, state: state, named: "detail-with-due")
    }

    @Test
    func rendersTheDetailOfAPriorityWithNoDue() throws {
        let (store, state, _) = try sample()
        let plain = try store.addPriority(title: "Ordenar el escritorio", level: .low, list: .week)
        try render(PriorityDetailView(priority: plain), store: store, state: state, named: "detail-no-due")
    }

    @Test
    func rendersTheTitleInEdit() throws {
        let (store, state, brief) = try sample()
        try render(
            PriorityDetailView(priority: brief, titleShowsEditState: true),
            store: store,
            state: state,
            named: "detail-title-edit"
        )
    }

    @Test
    func rendersTheConfirmationBar() throws {
        let (store, state, brief) = try sample()
        state.priorityFlow.toggleConfirmation(for: brief.id)
        try render(PriorityDetailView(priority: brief), store: store, state: state, named: "detail-confirm")
    }

    @Test
    func rendersADonePriority() throws {
        let (store, state, brief) = try sample()
        let done = try store.markDone(brief.id)
        try render(PriorityDetailView(priority: done), store: store, state: state, named: "detail-done")
    }

    @Test
    func rendersALongTitleAndAnOverdueDue() throws {
        let (store, state, _) = try sample()
        let long = try store.addPriority(
            title: "Revisar el MR pendiente de compass.ui y escribir los comentarios para el equipo de diseño",
            level: .medium,
            list: .today,
            dueAt: localDate("2026-10-12T09:00:00")
        )
        try render(PriorityDetailView(priority: long), store: store, state: state, named: "detail-long-overdue")
    }

    @Test
    func rendersTheFullPanelWithTheDetailOpen() throws {
        let (store, state, brief) = try sample()
        state.openDetail(brief.id)
        let url = try Screenshot.writeHosted(PanelView().environment(store).environment(state), named: "panel-detail")
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
        #expect(state.detailPriority?.id == brief.id)
    }
}
