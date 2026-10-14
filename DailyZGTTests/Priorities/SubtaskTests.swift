import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct SubtaskExpansionTests {
    let clock = TestClock("2026-10-12T10:24:00")

    @Test
    func everyRowStartsClosed() {
        let expansion = SubtaskExpansion()
        #expect(!expansion.isExpanded("a"))
    }

    @Test
    func theCaretOpensThenClosesOneRow() {
        var expansion = SubtaskExpansion()
        expansion.toggle("a")
        #expect(expansion.isExpanded("a"))
        expansion.toggle("a")
        #expect(!expansion.isExpanded("a"))
    }

    @Test
    func eachRowKeepsItsOwnState() {
        var expansion = SubtaskExpansion()
        expansion.toggle("a")
        expansion.toggle("b")
        expansion.toggle("a")
        #expect(!expansion.isExpanded("a"))
        #expect(expansion.isExpanded("b"))
    }

    @Test
    func theFlowHoldsTheStateAndTheDetailKeepsIt() throws {
        let store = try makeStore(clock)
        let state = PanelState(store: store)
        let first = try store.addPriority(title: "First", list: .today)
        try store.addSubtask(to: first.id, title: "Step")

        state.priorityFlow.toggleSubtasks(for: first.id)
        state.openDetail(first.id)
        state.closeDetail()
        state.select(tab: .notes)
        state.select(tab: .priorities)

        #expect(state.priorityFlow.isExpanded(first.id))
        state.priorityFlow.toggleSubtasks(for: first.id)
        #expect(!state.priorityFlow.isExpanded(first.id))
    }

    @Test
    func openingTheSubtasksDoesNotWriteToTheDatabase() throws {
        let store = try makeStore(clock)
        let flow = PriorityFlow(store: store)
        let first = try store.addPriority(title: "First", list: .today)
        flow.toggleSubtasks(for: first.id)
        #expect(try store.events(of: first.id).map(\.type) == [.created])
    }
}

@Suite
@MainActor
struct SubtaskActionsTests {
    let clock = TestClock("2026-10-12T10:24:00")

    private func makeActions(_ store: AppStore, _ priority: Priority) -> SubtaskActions {
        SubtaskActions(store: store, priorityID: priority.id)
    }

    private func eventTypes(_ store: AppStore, _ id: Priority.ID) throws -> [PriorityEventType] {
        try store.events(of: id).map(\.type)
    }

    @Test
    func addTrimsTheTitle() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "Parent", list: .today)
        let added = try makeActions(store, priority).add("  Escribir los criterios \n")
        #expect(added?.title == "Escribir los criterios")
        #expect(store.subtasks(of: priority.id).map(\.title) == ["Escribir los criterios"])
    }

    @Test
    func anEmptyOrBlankTitleAddsNothing() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "Parent", list: .today)
        let actions = makeActions(store, priority)

        #expect(try actions.add("") == nil)
        #expect(try actions.add("   ") == nil)
        #expect(try actions.add("\n\t ") == nil)

        #expect(store.subtasks(of: priority.id).isEmpty)
        #expect(try eventTypes(store, priority.id) == [.created])
    }

    @Test
    func addingKeepsSpacesInsideTheTitle() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "Parent", list: .today)
        try makeActions(store, priority).add("Pedir  review")
        #expect(store.subtasks(of: priority.id).map(\.title) == ["Pedir  review"])
    }

    @Test
    func theSubtasksFollowThePositionOrder() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "Parent", list: .today)
        let other = try store.addPriority(title: "Other", list: .today)
        let actions = makeActions(store, priority)

        try actions.add("one")
        try makeActions(store, other).add("elsewhere")
        try actions.add("two")
        let three = try #require(try actions.add("three"))
        try actions.toggle(three.id)

        let subtasks = store.subtasks(of: priority.id)
        #expect(subtasks.map(\.title) == ["one", "two", "three"])
        #expect(subtasks.map(\.position) == subtasks.map(\.position).sorted())
        #expect(store.subtasks(of: other.id).map(\.title) == ["elsewhere"])
    }

    @Test
    func aSubtaskCheckboxToggleNeedsNoConfirmation() throws {
        let store = try makeStore(clock)
        let state = PanelState(store: store)
        let priority = try store.addPriority(title: "Parent", list: .today)
        let step = try #require(try makeActions(store, priority).add("Step"))

        try makeActions(store, priority).toggle(step.id)

        #expect(state.priorityFlow.confirmingID == nil)
        #expect(state.priorityFlow.undo == nil)
        #expect(store.subtasks(of: priority.id).first?.isDone == true)
        #expect(store.priority(id: priority.id)?.isDone == false)
    }

    @Test
    func doneWritesSubtaskDoneAndReopenWritesEdited() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "Parent", list: .today)
        let actions = makeActions(store, priority)
        let step = try #require(try actions.add("Step"))
        #expect(try eventTypes(store, priority.id) == [.created, .edited])

        try actions.toggle(step.id)
        #expect(try eventTypes(store, priority.id) == [.created, .edited, .subtaskDone])

        try actions.toggle(step.id)
        #expect(try eventTypes(store, priority.id) == [.created, .edited, .subtaskDone, .edited])
        #expect(store.subtasks(of: priority.id).first?.isDone == false)
    }

    @Test
    func deleteRemovesTheSubtaskAndWritesEdited() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "Parent", list: .today)
        let actions = makeActions(store, priority)
        let first = try #require(try actions.add("one"))
        try actions.add("two")

        try store.deleteSubtask(first.id)

        #expect(store.subtasks(of: priority.id).map(\.title) == ["two"])
        #expect(store.subtaskProgress(of: priority.id) == SubtaskProgress(done: 0, total: 1))
        #expect(try eventTypes(store, priority.id) == [.created, .edited, .edited, .edited])
    }

    @Test
    func theProgressLabelsFollowEachChange() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "Parent", list: .today)
        let actions = makeActions(store, priority)
        #expect(store.subtaskProgress(of: priority.id).ratioLabel == nil)
        #expect(PriorityDetailLabels.subtasks(store.subtaskProgress(of: priority.id)) == nil)

        let first = try #require(try actions.add("one"))
        try actions.add("two")
        try actions.add("three")
        #expect(store.subtaskProgress(of: priority.id).ratioLabel == "0/3")

        try actions.toggle(first.id)
        let progress = store.subtaskProgress(of: priority.id)
        #expect(progress.ratioLabel == "1/3")
        #expect(PriorityDetailLabels.subtasks(progress) == "1/3 subtareas")

        try store.deleteSubtask(first.id)
        #expect(store.subtaskProgress(of: priority.id).ratioLabel == "0/2")
    }

    @Test
    func theConfirmationTextFollowsEachSubtaskChange() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "Parent", list: .today)
        let actions = makeActions(store, priority)
        func label() -> String? { store.subtaskProgress(of: priority.id).openSubtasksLabel }

        #expect(label() == nil)
        let first = try #require(try actions.add("one"))
        #expect(label() == "Queda 1 subtarea abierta.")
        let second = try #require(try actions.add("two"))
        try actions.add("three")
        #expect(label() == "Quedan 3 subtareas abiertas.")

        try actions.toggle(first.id)
        #expect(label() == "Quedan 2 subtareas abiertas.")
        try actions.toggle(second.id)
        #expect(label() == "Queda 1 subtarea abierta.")
        try actions.toggle(first.id)
        #expect(label() == "Quedan 2 subtareas abiertas.")
    }
}

@Suite
@MainActor
struct SubtaskRenderTests {
    let clock = TestClock("2026-10-12T10:24:00")

    private func sample() throws -> (AppStore, PanelState, Priority) {
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
        let second = try store.addSubtask(to: brief.id, title: "Escribir los criterios")
        try store.addSubtask(to: brief.id, title: "Pedir review")
        try store.toggleSubtask(first.id)
        try store.toggleSubtask(second.id)
        try store.toggleSubtask(second.id)
        try store.addPriority(title: "1:1 con el equipo", level: .medium, list: .today, dueAt: localDate("2026-10-12T16:00:00"))
        return (store, PanelState(store: store), brief)
    }

    private func render(_ view: some View, named name: String) throws {
        let url = try Screenshot.writeHosted(view, named: name)
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func rendersTheRowWithItsSubtasksOpen() throws {
        let (store, state, brief) = try sample()
        state.priorityFlow.toggleSubtasks(for: brief.id)
        try render(
            PriorityListView(list: .today).environment(store).environment(state).panelChrome(),
            named: "subtasks-row-open"
        )
    }

    @Test
    func rendersTheRowWithItsSubtasksClosed() throws {
        let (store, state, _) = try sample()
        try render(
            PriorityListView(list: .today).environment(store).environment(state).panelChrome(),
            named: "subtasks-row-closed"
        )
    }

    @Test
    func rendersTheRowWithTheConfirmationAndTheSubtasksOpen() throws {
        let (store, state, brief) = try sample()
        state.priorityFlow.toggleSubtasks(for: brief.id)
        state.priorityFlow.toggleConfirmation(for: brief.id)
        try render(
            PriorityListView(list: .today).environment(store).environment(state).panelChrome(),
            named: "subtasks-row-confirm"
        )
    }

    @Test
    func rendersTheDetailWithTheSubtasksAndTheInput() throws {
        let (store, state, brief) = try sample()
        try render(
            PriorityDetailView(priority: brief).environment(store).environment(state).panelChrome(),
            named: "subtasks-detail"
        )
    }
}
