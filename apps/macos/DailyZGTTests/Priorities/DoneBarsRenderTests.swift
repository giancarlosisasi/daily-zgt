import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct DoneBarsRenderTests {
    let clock = TestClock("2026-10-12T10:24:00")

    private func render(_ view: some View, named name: String) throws {
        let url = try Screenshot.writeHosted(view.panelChrome(), named: name)
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    private func panel(_ store: AppStore, _ flow: PriorityFlow) -> some View {
        PriorityListView(list: .today)
            .environment(store)
            .environment(PanelState(store: store, priorityFlow: flow))
    }

    private func renderPanel(_ store: AppStore, _ flow: PriorityFlow, named name: String) throws {
        let view = PanelView()
            .environment(store)
            .environment(PanelState(store: store, priorityFlow: flow))
        let url = try Screenshot.writeHosted(view, named: name)
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    private func store() throws -> (AppStore, Priority, Priority) {
        let store = try makeStore(clock)
        let plain = try store.addPriority(title: "Revisar el MR pendiente de compass.ui", level: .high, list: .today, dueAt: localDate("2026-10-12T11:00:00"))
        let brief = try store.addPriority(title: "Terminar el brief de Tailwind v4", level: .medium, list: .today)
        let first = try store.addSubtask(to: brief.id, title: "Listar las apps piloto")
        try store.addSubtask(to: brief.id, title: "Escribir los criterios")
        try store.addSubtask(to: brief.id, title: "Pedir review")
        try store.toggleSubtask(first.id)
        return (store, plain, brief)
    }

    @Test
    func rendersTheConfirmationBarWithNoOpenSubtasks() throws {
        let (store, plain, _) = try store()
        let flow = PriorityFlow(store: store)
        flow.toggleConfirmation(for: plain.id)
        try render(panel(store, flow), named: "done-confirm-plain")
    }

    @Test
    func rendersTheConfirmationBarWithOpenSubtasks() throws {
        let (store, _, brief) = try store()
        let flow = PriorityFlow(store: store)
        flow.toggleConfirmation(for: brief.id)
        try render(panel(store, flow), named: "done-confirm-subtasks")
    }

    @Test
    func rendersTheUndoBar() throws {
        let (store, plain, _) = try store()
        let flow = PriorityFlow(store: store)
        flow.confirmDone(plain.id)
        #expect(flow.undo?.remainingFraction(at: store.now()) == 1)
        try renderPanel(store, flow, named: "done-undo-bar")
    }

    @Test
    func rendersTheUndoBarWithALongTitle() throws {
        let store = try makeStore(clock)
        let long = try store.addPriority(
            title: "Preparar la presentación trimestral con los números de todas las áreas del equipo",
            list: .today
        )
        let flow = PriorityFlow(store: store)
        flow.confirmDone(long.id)
        try renderPanel(store, flow, named: "done-undo-bar-long")
    }
}
