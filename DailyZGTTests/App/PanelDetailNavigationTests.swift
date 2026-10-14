import Testing
@testable import DailyZGT

@Suite
@MainActor
struct PanelDetailNavigationTests {
    let clock = TestClock("2026-10-12T10:24:00")
    let recorder = ScheduleRecorder()

    private func makeState(_ store: AppStore) -> PanelState {
        PanelState(store: store, priorityFlow: PriorityFlow(store: store, schedule: recorder.schedule))
    }

    @Test
    func noPriorityIsOpenAtStart() throws {
        let state = makeState(try makeStore(clock))
        #expect(state.openPriorityID == nil)
        #expect(state.detailPriority == nil)
    }

    @Test
    func openingAPriorityByIDShowsItAndSetsTheTabAndTheList() throws {
        let store = try makeStore(clock)
        let state = makeState(store)
        let week = try store.addPriority(title: "Week item", list: .week)
        state.select(tab: .notes)

        state.openDetail(week.id)
        #expect(state.openPriorityID == week.id)
        #expect(state.detailPriority?.id == week.id)
        #expect(state.tab == .priorities)
        #expect(state.scope == .week)
    }

    @Test
    func backReturnsToTheList() throws {
        let store = try makeStore(clock)
        let state = makeState(store)
        let first = try store.addPriority(title: "First", list: .today)

        state.openDetail(first.id)
        state.closeDetail()
        #expect(state.openPriorityID == nil)
        #expect(state.detailPriority == nil)
        #expect(state.scope == .today)
        #expect(store.priority(id: first.id) != nil)
    }

    @Test
    func openingAnUnknownOrDoneIDDoesNothing() throws {
        let store = try makeStore(clock)
        let state = makeState(store)
        let done = try store.addPriority(title: "Done", list: .today)
        try store.markDone(done.id)

        state.openDetail("missing")
        #expect(state.openPriorityID == nil)
        state.openDetail(done.id)
        #expect(state.openPriorityID == nil)
    }

    @Test
    func openingAnotherPriorityReplacesTheOpenOne() throws {
        let store = try makeStore(clock)
        let state = makeState(store)
        let first = try store.addPriority(title: "First", list: .today)
        let second = try store.addPriority(title: "Second", list: .today)

        state.openDetail(first.id)
        state.openDetail(second.id)
        #expect(state.detailPriority?.id == second.id)
    }

    @Test
    func aTabClickClosesTheDetailEvenOnTheSameTab() throws {
        let store = try makeStore(clock)
        let state = makeState(store)
        let first = try store.addPriority(title: "First", list: .today)

        state.openDetail(first.id)
        state.select(tab: .priorities)
        #expect(state.openPriorityID == nil)

        state.openDetail(first.id)
        state.select(tab: .notes)
        #expect(state.openPriorityID == nil)
        #expect(state.tab == .notes)
    }

    @Test
    func theDetailFollowsAMoveToTheOtherList() throws {
        let store = try makeStore(clock)
        let state = makeState(store)
        let first = try store.addPriority(title: "First", list: .today)

        state.openDetail(first.id)
        try store.movePriority(first.id, to: .week)
        state.select(scope: .week)
        #expect(state.detailPriority?.id == first.id)
        #expect(state.detailPriority?.list == .week)
        #expect(state.scope == .week)
    }

    @Test
    func aDeletedPriorityReturnsToTheList() throws {
        let store = try makeStore(clock)
        let state = makeState(store)
        let first = try store.addPriority(title: "First", list: .today)

        state.openDetail(first.id)
        state.priorityFlow.delete(first.id)
        #expect(state.detailPriority == nil)
        state.closeDetailIfGone()
        #expect(state.openPriorityID == nil)
    }

    @Test
    func aPriorityDoneByAnotherWriterReturnsToTheListAndDoesNotComeBack() throws {
        let store = try makeStore(clock)
        let state = makeState(store)
        let first = try store.addPriority(title: "First", list: .today)

        state.openDetail(first.id)
        try store.markDone(first.id)
        #expect(state.detailPriority == nil)
        state.closeDetailIfGone()
        #expect(state.openPriorityID == nil)

        try store.restorePriority(first.id)
        #expect(state.detailPriority == nil)
    }

    @Test
    func closeIfGoneKeepsAPriorityThatStillExists() throws {
        let store = try makeStore(clock)
        let state = makeState(store)
        let first = try store.addPriority(title: "First", list: .today)

        state.openDetail(first.id)
        state.closeDetailIfGone()
        #expect(state.openPriorityID == first.id)
    }

    @Test
    func openingAndClosingClearAnOpenConfirmation() throws {
        let store = try makeStore(clock)
        let state = makeState(store)
        let first = try store.addPriority(title: "First", list: .today)
        let second = try store.addPriority(title: "Second", list: .today)

        state.priorityFlow.toggleConfirmation(for: second.id)
        state.openDetail(first.id)
        #expect(state.priorityFlow.confirmingID == nil)

        state.priorityFlow.toggleConfirmation(for: first.id)
        state.closeDetail()
        #expect(state.priorityFlow.confirmingID == nil)
    }

    @Test
    func doneFromTheDetailAsksFirstThenReturnsToTheListWithTheUndo() throws {
        let store = try makeStore(clock)
        let state = makeState(store)
        let first = try store.addPriority(title: "Send the report", list: .today)
        state.openDetail(first.id)

        state.priorityFlow.toggleConfirmation(for: first.id)
        #expect(state.priorityFlow.isConfirming(first.id))
        #expect(store.priority(id: first.id)?.isDone == false)

        state.priorityFlow.cancelConfirmation()
        #expect(state.detailPriority?.id == first.id)
        #expect(store.priority(id: first.id)?.isDone == false)

        state.priorityFlow.toggleConfirmation(for: first.id)
        state.priorityFlow.confirmDone(first.id)
        #expect(store.priority(id: first.id)?.isDone == true)
        #expect(state.detailPriority == nil)
        #expect(state.priorityFlow.undo?.title == "Send the report")
        #expect(try store.events(of: first.id).map(\.type) == [.created, .done])
    }
}
