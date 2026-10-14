import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct PanelViewTests {
    private func seededStore(_ clock: TestClock) throws -> AppStore {
        let store = try makeStore(clock)
        try store.addPriority(title: "Revisar el MR pendiente de compass.ui", level: .high, list: .today, dueAt: localDate("2026-10-12T09:00:00"))
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
        try store.addPriority(title: "1:1 con el equipo", level: .medium, list: .today, dueAt: localDate("2026-10-12T16:00:00"))
        try store.addPriority(title: "Preparar la demo del viernes", level: .low, list: .today, dueAt: localDate("2026-10-16T10:00:00"))
        try store.addPriority(title: "Ordenar el escritorio", level: .low, list: .today)
        let done = try store.addPriority(title: "Mandar el reporte", level: .medium, list: .today)
        try store.markDone(done.id)
        try store.addPriority(title: "Cerrar el brief de la semana", level: .high, list: .week, dueAt: localDate("2026-10-15T12:00:00"))
        try store.addPriority(title: "Planear el sprint", level: .medium, list: .week)
        try store.addPriority(title: "Limpiar el backlog", level: .low, list: .week, dueAt: localDate("2026-10-12T10:30:00"))
        try store.saveNote(
            "Hablar con Ana sobre el brief.\nRevisar el MR de compass.ui antes de la demo.",
            scope: .day
        )
        return store
    }

    private func render(_ name: String, tab: PanelTab, scope: PriorityList) throws {
        let store = try seededStore(TestClock("2026-10-12T10:24:00"))
        let state = PanelState(store: store)
        state.select(tab: tab)
        state.select(scope: scope)
        let view = PanelView().environment(store).environment(state)
        let url = try Screenshot.writeHosted(view, named: name)
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func rendersPrioritiesWithToday() throws {
        try render("panel-priorities-today", tab: .priorities, scope: .today)
    }

    @Test
    func rendersPrioritiesWithWeek() throws {
        try render("panel-priorities-week", tab: .priorities, scope: .week)
    }

    @Test
    func rendersNotes() throws {
        try render("panel-notes", tab: .notes, scope: .today)
    }

    @Test
    func rendersThePanelWithNoPriority() throws {
        let store = try makeStore(TestClock("2026-10-12T10:24:00"))
        let view = PanelView().environment(store).environment(PanelState(store: store))
        let url = try Screenshot.writeHosted(view, named: "panel-empty")
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func rendersTheDatabaseError() throws {
        let url = try Screenshot.write(DatabaseErrorView(), named: "panel-database-error")
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func theTestHostUsesAnInMemoryDatabase() {
        #expect(AppDatabase.isTestHost)
        if case .ready = AppBoot.start() {} else {
            Issue.record("The boot must be ready in a test run.")
        }
    }
}
