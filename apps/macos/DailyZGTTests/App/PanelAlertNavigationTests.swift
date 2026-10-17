import Testing
@testable import DailyZGT

@Suite
@MainActor
struct PanelAlertNavigationTests {
    let clock = TestClock("2026-10-12T10:24:00")
    let recorder = ScheduleRecorder()

    private func makeState(_ store: AppStore) -> PanelState {
        PanelState(store: store, priorityFlow: PriorityFlow(store: store, schedule: recorder.schedule))
    }

    @Test
    func showingAPriorityInTheListSelectsItsListAndHighlightsIt() throws {
        let store = try makeStore(clock)
        let state = makeState(store)
        let week = try store.addPriority(title: "Week item", list: .week)
        state.select(tab: .notes)

        state.showInList(week.id)

        #expect(state.tab == .priorities)
        #expect(state.scope == .week)
        #expect(state.detailPriority == nil)
        #expect(state.priorityFlow.highlightedID == week.id)
        #expect(state.priorityFlow.scrollTargetID == week.id)
        #expect(recorder.entries.map(\.delay) == [.milliseconds(1400)])
        recorder.fire(0)
        #expect(state.priorityFlow.highlightedID == nil)
    }

    @Test
    func showingAPriorityInTheListClosesTheDetailOfAnotherPriority() throws {
        let store = try makeStore(clock)
        let state = makeState(store)
        let first = try store.addPriority(title: "First", list: .today)
        let second = try store.addPriority(title: "Second", list: .today)
        state.openDetail(first.id)

        state.showInList(second.id)

        #expect(state.detailPriority == nil)
        #expect(state.priorityFlow.highlightedID == second.id)
    }

    @Test
    func showingNoPriorityOpensTheListOfToday() throws {
        let store = try makeStore(clock)
        let state = makeState(store)
        state.select(tab: .notes)
        state.select(scope: .week)

        state.showInList(nil)

        #expect(state.tab == .priorities)
        #expect(state.scope == .today)
        #expect(state.priorityFlow.highlightedID == nil)
        #expect(recorder.entries.isEmpty)
    }

    @Test
    func showingADoneOrUnknownPriorityHighlightsNothing() throws {
        let store = try makeStore(clock)
        let state = makeState(store)
        let done = try store.addPriority(title: "Done", list: .week)
        try store.markDone(done.id)

        state.showInList(done.id)
        state.showInList("missing")

        #expect(state.scope == .today)
        #expect(state.priorityFlow.highlightedID == nil)
    }

    @Test
    func theScrollTargetIsSetByShowInListAndClearedWhenTheViewHandlesIt() throws {
        let store = try makeStore(clock)
        let state = makeState(store)
        let item = try store.addPriority(title: "Below the fold", list: .today)
        #expect(state.priorityFlow.scrollTargetID == nil)

        state.showInList(item.id)
        #expect(state.priorityFlow.scrollTargetID == item.id)

        state.priorityFlow.scrollWasHandled("other")
        #expect(state.priorityFlow.scrollTargetID == item.id)
        state.priorityFlow.scrollWasHandled(item.id)
        #expect(state.priorityFlow.scrollTargetID == nil)
        #expect(state.priorityFlow.highlightedID == item.id)
    }

    @Test
    func theScrollTargetClearsWhenTheHighlightEnds() throws {
        let store = try makeStore(clock)
        let flow = PriorityFlow(store: store, schedule: recorder.schedule)
        let item = try store.addPriority(title: "Item", list: .today)

        flow.flash(item.id)
        #expect(flow.scrollTargetID == item.id)
        recorder.fire(0)
        #expect(flow.scrollTargetID == nil)
        #expect(flow.highlightedID == nil)
    }

    @Test
    func aNewFlashMovesTheScrollTargetAndTheOldTimerKeepsIt() throws {
        let store = try makeStore(clock)
        let flow = PriorityFlow(store: store, schedule: recorder.schedule)
        let first = try store.addPriority(title: "First", list: .today)
        let second = try store.addPriority(title: "Second", list: .today)

        flow.flash(first.id)
        flow.flash(second.id)
        #expect(flow.scrollTargetID == second.id)
        recorder.fire(0)
        #expect(flow.scrollTargetID == second.id)
        recorder.fire(1)
        #expect(flow.scrollTargetID == nil)
    }

    @Test
    func showingNoPriorityOrADoneOneSetsNoScrollTarget() throws {
        let store = try makeStore(clock)
        let state = makeState(store)
        let done = try store.addPriority(title: "Done", list: .week)
        try store.markDone(done.id)

        state.showInList(nil)
        state.showInList(done.id)
        state.showInList("missing")

        #expect(state.priorityFlow.scrollTargetID == nil)
    }
}
