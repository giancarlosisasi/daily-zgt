import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct PriorityListViewTests {
    let clock = TestClock("2026-10-12T10:24:00")

    private func sampleStore() throws -> AppStore {
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
        try store.addSubtask(to: brief.id, title: "Pedir review")
        try store.toggleSubtask(first.id)
        try store.addPriority(title: "1:1 con el equipo", level: .medium, list: .today, dueAt: localDate("2026-10-12T16:00:00"))
        try store.addPriority(title: "Mandar el reporte", level: .medium, list: .today, dueAt: localDate("2026-10-12T11:44:00"))
        try store.addPriority(title: "Preparar la demo del viernes", level: .low, list: .today, dueAt: localDate("2026-10-16T10:00:00"))
        try store.addPriority(title: "Ordenar el escritorio", level: .low, list: .today)
        return store
    }

    private func render(_ view: some View, named name: String) throws {
        let url = try Screenshot.writeHosted(view.panelChrome(), named: name)
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func openRowsFollowTheManualOrderNotTheLevelOrTheDue() throws {
        let store = try makeStore(clock)
        try store.addPriority(title: "low no due", level: .low, list: .today)
        try store.addPriority(title: "high early", level: .high, list: .today, dueAt: localDate("2026-10-12T12:00:00"))
        try store.addPriority(title: "medium late", level: .medium, list: .today, dueAt: localDate("2026-10-12T17:00:00"))
        try store.addPriority(title: "week item", level: .high, list: .week, dueAt: localDate("2026-10-12T08:00:00"))

        #expect(store.openPriorities(in: .today).map(\.title) == ["low no due", "high early", "medium late"])
        #expect(store.openPriorities(in: .week).map(\.title) == ["week item"])
    }

    @Test
    func rendersTheListWithTheThreeLevelsAndEveryDueState() throws {
        let store = try sampleStore()
        try render(PriorityListView(list: .today).environment(store).environment(PanelState(store: store)), named: "priorities-list")
    }

    @Test
    func rendersAHoveredRowWithTheRemoveButton() throws {
        let store = try sampleStore()
        let priority = try #require(store.openPriorities(in: .today).dropFirst().first)
        let row = PriorityRow(
            priority: priority,
            progress: store.subtaskProgress(of: priority.id),
            now: clock.date,
            isHoveringAtStart: true
        )
        try render(row, named: "priorities-row-hover")
    }

    @Test
    func rendersTheListWhileARowIsDraggedWithTheDropLine() throws {
        let store = try sampleStore()
        let state = PanelState(store: store)
        let first = try #require(store.openPriorities(in: .today).first)
        state.priorityFlow.startDrag(first.id)
        state.priorityFlow.hover(gap: 3, in: .today)
        try render(PriorityListView(list: .today).environment(store).environment(state), named: "priorities-drag")
    }

    @Test
    func rendersTheDragPreview() throws {
        try render(DragPreview(title: "Terminar el brief de Tailwind v4", level: .high), named: "priorities-drag-preview")
    }

    @Test
    func rendersAHighlightedRow() throws {
        let store = try sampleStore()
        let priority = try #require(store.openPriorities(in: .today).first)
        let row = PriorityRow(priority: priority, progress: SubtaskProgress(done: 0, total: 0), now: clock.date, isHighlighted: true)
        try render(row, named: "priorities-row-highlight")
    }

    @Test
    func rendersTheEmptyListWithNoPriorities() throws {
        let store = try makeStore(clock)
        try render(PriorityListView(list: .today).environment(store).environment(PanelState(store: store)), named: "priorities-empty")
    }

    @Test
    func rendersTheEmptyListWhenAllAreDone() throws {
        let store = try makeStore(clock)
        let done = try store.addPriority(title: "Hecha", list: .today)
        try store.markDone(done.id)
        try render(PriorityListView(list: .today).environment(store).environment(PanelState(store: store)), named: "priorities-all-done")
    }

    @Test
    func rendersALongListThatScrollsAfter330Points() throws {
        let store = try makeStore(clock)
        for index in 1...14 {
            try store.addPriority(title: "Prioridad número \(index)", level: .medium, list: .today)
        }
        try render(PriorityListView(list: .today).environment(store).environment(PanelState(store: store)), named: "priorities-long")
    }

    @Test
    func rendersTheDesktopWindowWithTheListAndTheOpenDetail() throws {
        let store = try sampleStore()
        let state = PanelState(store: store)
        let brief = try #require(store.openPriorities(in: .today).first { $0.title.hasPrefix("Terminar") })
        state.openDetail(brief.id)
        let view = MainWindowView()
            .environment(store)
            .environment(state)
            .frame(width: Theme.Window.defaultWidth, height: Theme.Window.defaultHeight)
        let url = try Screenshot.writeHosted(view, named: "window-priorities")
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func rendersTheDesktopWindowWithNoOpenDetail() throws {
        let store = try sampleStore()
        let view = MainWindowView()
            .environment(store)
            .environment(PanelState(store: store))
            .frame(width: Theme.Window.defaultWidth, height: Theme.Window.defaultHeight)
        let url = try Screenshot.writeHosted(view, named: "window-empty-detail")
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func rendersTheDesktopWindowOnTheNotesTab() throws {
        let store = try sampleStore()
        let state = PanelState(store: store)
        try store.saveNote("Revisar el brief antes de las 11.\nLlamar a Ana.", scope: .day)
        state.select(tab: .notes)
        let view = MainWindowView()
            .environment(store)
            .environment(state)
            .frame(width: Theme.Window.defaultWidth, height: Theme.Window.defaultHeight)
        let url = try Screenshot.writeHosted(view, named: "window-notes")
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func rendersThePanelWithTheList() throws {
        let store = try sampleStore()
        let state = PanelState(store: store)
        let url = try Screenshot.writeHosted(PanelView().environment(store).environment(state), named: "priorities-panel")
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }
}
