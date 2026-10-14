import AppKit
import Foundation
import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct DoneHistoryTests {
    let clock = TestClock("2026-10-05T08:00:00")
    let recorder = ScheduleRecorder()
    let now = localDate("2026-10-13T10:00:00")

    private func sampleStore() throws -> AppStore {
        let store = try makeStore(clock)
        try addDone(store, clock, title: "Pagar el hosting", at: "2026-10-08T17:30:00")
        try addDone(store, clock, title: "Enviar la factura", at: "2026-10-08T09:10:00")
        try addDone(store, clock, title: "Responder a Ana", at: "2026-10-12T08:45:00")
        try addDone(store, clock, title: "Revisar el MR", at: "2026-10-12T09:20:00")
        try addDone(store, clock, title: "Llamar al banco", at: "2026-10-13T08:00:00")
        try store.addPriority(title: "Terminar el brief de Tailwind v4", level: .high, list: .today)
        try store.addPriority(title: "1:1 con el equipo", level: .medium, list: .today)
        clock.date = now
        return store
    }

    private func render(_ view: some View, named name: String) throws {
        let url = try Screenshot.writeHosted(view.panelChrome(), named: name)
        #expect(try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) > 0)
    }

    private func height(_ view: some View) -> CGFloat {
        NSHostingView(rootView: view.panelChrome()).fittingSize.height
    }

    private func olderIDs(_ store: AppStore, _ list: PriorityList = .today) throws -> [Priority.ID] {
        try store.donePriorities(in: list, atOrBefore: DoneWindow.cutoff(now: store.now())).map(\.id)
    }

    @Test
    func theGroupsFollowTheLocalDayNewestFirst() throws {
        let store = try sampleStore()
        let groups = DoneHistory.groups(from: try store.donePriorities(in: .today, atOrBefore: DoneWindow.cutoff(now: now)))
        #expect(groups.map(\.day) == ["2026-10-12", "2026-10-08"])
        #expect(groups[0].priorities.map(\.title) == ["Revisar el MR", "Responder a Ana"])
        #expect(groups[1].priorities.map(\.title) == ["Pagar el hosting", "Enviar la factura"])
        #expect(groups[0].date == localDate("2026-10-12T09:20:00"))
    }

    @Test
    func theGroupsSplitAtLocalMidnight() throws {
        let store = try makeStore(clock)
        try addDone(store, clock, title: "Late", at: "2026-10-08T23:59:59")
        try addDone(store, clock, title: "Early", at: "2026-10-09T00:00:00")
        let groups = DoneHistory.groups(from: try store.donePriorities(in: .today, atOrBefore: now))
        #expect(groups.map(\.day) == ["2026-10-09", "2026-10-08"])
        #expect(groups.map { $0.priorities.map(\.title) } == [["Early"], ["Late"]])
    }

    @Test
    func theGroupsCrossAMonthBoundary() throws {
        let store = try makeStore(clock)
        try addDone(store, clock, title: "October", at: "2026-10-01T09:00:00")
        try addDone(store, clock, title: "September", at: "2026-09-30T09:00:00")
        let groups = DoneHistory.groups(from: try store.donePriorities(in: .today, atOrBefore: now))
        #expect(groups.map(\.day) == ["2026-10-01", "2026-09-30"])
    }

    @Test
    func noRowsGiveNoGroups() {
        #expect(DoneHistory.groups(from: []).isEmpty)
    }

    @Test
    func theOrderInADayIsStableForTheSameSecond() throws {
        let store = try makeStore(clock)
        let first = try store.addPriority(title: "First", list: .today)
        let second = try store.addPriority(title: "Second", list: .today)
        clock.date = localDate("2026-10-08T09:00:00")
        try store.markDone(first.id)
        try store.markDone(second.id)
        let rows = try store.donePriorities(in: .today, atOrBefore: now)
        #expect(DoneHistory.groups(from: rows.reversed()).first?.priorities.map(\.title) == ["Second", "First"])
        #expect(DoneHistory.groups(from: rows).first?.priorities.map(\.title) == ["Second", "First"])
    }

    @Test
    func theDayTitlesUseTheSpanishLabelOfThePanel() {
        let today = localDate("2026-10-13T09:00:00")
        #expect(PanelLabels.historyDay(for: localDate("2026-10-13T00:00:00"), now: today) == "Hoy")
        #expect(PanelLabels.historyDay(for: localDate("2026-10-12T23:59:59"), now: today) == "Ayer")
        #expect(PanelLabels.historyDay(for: localDate("2026-10-12T00:00:00"), now: today) == "Ayer")
        #expect(PanelLabels.historyDay(for: localDate("2026-10-11T12:00:00"), now: today) == "Domingo 11 oct")
        #expect(PanelLabels.historyDay(for: localDate("2026-10-08T12:00:00"), now: today) == "Jueves 8 oct")
        #expect(PanelLabels.historyDay(for: localDate("2026-09-30T12:00:00"), now: today) == "Miércoles 30 sep")
        #expect(PanelLabels.historyDay(for: localDate("2026-10-05T12:00:00"), now: localDate("2026-10-12T09:00:00")) == "Lunes 5 oct")
    }

    @Test
    func yesterdayAcrossAMonthBoundaryReadsAyer() {
        #expect(PanelLabels.historyDay(for: localDate("2026-09-30T08:00:00"), now: localDate("2026-10-01T09:00:00")) == "Ayer")
    }

    @Test
    func hechasListsAndCountsOnlyTheLast24Hours() throws {
        let store = try sampleStore()
        let cutoff = DoneWindow.cutoff(now: now)
        let recent = try store.donePriorities(in: .today, after: cutoff)
        #expect(recent.map(\.title) == ["Llamar al banco"])
        #expect(DoneSection.headerTitle(count: recent.count) == "Hechas (1)")
        #expect(try store.doneCount(in: .today, atOrBefore: cutoff) == 4)
    }

    @Test
    func aDonePriorityLeavesHechasWhen24HoursPassWhileThePanelIsOpen() throws {
        let store = try sampleStore()
        let state = PanelState(store: store)
        state.toggleDone()
        func section(at date: Date) -> some View {
            DoneSectionContent(list: .today, now: date).environment(store).environment(state)
        }
        let doneAt = localDate("2026-10-13T08:00:00")
        let inside = height(section(at: doneAt.addingTimeInterval(DoneWindow.length - 60)))
        let outside = height(section(at: doneAt.addingTimeInterval(DoneWindow.length)))
        #expect(outside < inside)

        let recentBefore = try store.donePriorities(in: .today, after: DoneWindow.cutoff(now: doneAt.addingTimeInterval(DoneWindow.length - 60)))
        let recentAfter = try store.donePriorities(in: .today, after: DoneWindow.cutoff(now: doneAt.addingTimeInterval(DoneWindow.length)))
        #expect(recentBefore.map(\.title) == ["Llamar al banco"])
        #expect(recentAfter.isEmpty)
        #expect(try store.doneCount(in: .today, atOrBefore: DoneWindow.cutoff(now: doneAt.addingTimeInterval(DoneWindow.length))) == 5)
    }

    @Test
    func theHistorialRowShowsOnlyWhenOlderPrioritiesExist() throws {
        let storeWith = try sampleStore()
        let stateWith = PanelState(store: storeWith)
        stateWith.toggleDone()
        let withHistory = height(DoneSectionContent(list: .today, now: now).environment(storeWith).environment(stateWith))

        let storeWithout = try makeStore(clock)
        try addDone(storeWithout, clock, title: "Llamar al banco", at: "2026-10-13T08:00:00")
        let stateWithout = PanelState(store: storeWithout)
        stateWithout.toggleDone()
        let withoutHistory = height(DoneSectionContent(list: .today, now: now).environment(storeWithout).environment(stateWithout))

        #expect(withHistory > withoutHistory)
    }

    @Test
    func theHistorialRowIsHiddenWhileHechasIsClosed() throws {
        let store = try sampleStore()
        let state = PanelState(store: store)
        let closed = height(DoneSectionContent(list: .today, now: now).environment(store).environment(state))
        state.toggleDone()
        let open = height(DoneSectionContent(list: .today, now: now).environment(store).environment(state))
        #expect(open > closed)
    }

    @Test
    func hechasShowsWhenOnlyOlderPrioritiesExist() throws {
        let store = try makeStore(clock)
        try addDone(store, clock, title: "Old", at: "2026-10-08T09:00:00")
        clock.date = now
        let state = PanelState(store: store)
        let visible = height(DoneSectionContent(list: .today, now: now).environment(store).environment(state))
        let empty = try makeStore(clock)
        let hidden = height(DoneSectionContent(list: .today, now: now).environment(empty).environment(PanelState(store: empty)))
        #expect(visible > hidden)
    }

    @Test
    func regresarFromTheHistoryRestoresThePriorityWithTheHighlight() throws {
        let store = try sampleStore()
        let flow = PriorityFlow(store: store, schedule: recorder.schedule)
        let target = try #require(store.donePriorities(in: .today).first { $0.title == "Responder a Ana" })
        #expect(try olderIDs(store).contains(target.id))

        flow.restore(target.id)

        #expect(store.priority(id: target.id)?.isDone == false)
        #expect(store.openPriorities(in: .today).map(\.title).contains("Responder a Ana"))
        #expect(!(try olderIDs(store)).contains(target.id))
        #expect(try store.events(of: target.id).map(\.type) == [.created, .done, .restored])
        #expect(flow.highlightedID == target.id)
        #expect(flow.scrollTargetID == target.id)
        #expect(!flow.writeFailed)
    }

    @Test
    func regresarFromTheHistoryKeepsTheRulesOfTheDailyRepeat() throws {
        let store = try makeStore(clock)
        let daily = try addDaily(store, title: "Meditar")
        clock.date = localDate("2026-10-08T07:00:00")
        try store.markDone(daily.id)
        clock.date = localDate("2026-10-09T07:00:00")
        let copies = try store.addRepeatCopies()
        #expect(copies.count == 1)
        clock.date = now
        let flow = PriorityFlow(store: store, schedule: recorder.schedule)

        flow.restore(daily.id)

        #expect(store.priority(id: daily.id)?.isDone == false)
        #expect(store.priority(id: copies[0].id) == nil)
        #expect(try openCopiesBySeries(store) == [1])
    }

    @Test
    func deletingFromTheHistoryRemovesTheRow() throws {
        let store = try sampleStore()
        let flow = PriorityFlow(store: store, schedule: recorder.schedule)
        let target = try #require(try olderIDs(store).first)
        flow.delete(target)
        #expect(store.priority(id: target) == nil)
        #expect(try olderIDs(store).count == 3)
    }

    @Test
    func theHistoryIsClosedAtStart() throws {
        let state = PanelState(store: try makeStore(clock))
        #expect(!state.isHistoryOpen)
        #expect(state.page == .browse)
    }

    @Test
    func openAndBackToggleTheHistory() throws {
        let state = PanelState(store: try sampleStore())
        state.openHistory()
        #expect(state.isHistoryOpen)
        #expect(state.page == .history)
        state.closeHistory()
        #expect(!state.isHistoryOpen)
        #expect(state.page == .browse)
    }

    @Test
    func openingTheHistoryClosesTheDetailAndTheSettings() throws {
        let store = try sampleStore()
        let priority = try #require(store.openPriorities(in: .today).first)
        let state = PanelState(store: store)
        state.openDetail(priority.id)
        state.openHistory()
        #expect(state.isHistoryOpen)
        #expect(state.detailPriority == nil)

        state.openSettings()
        #expect(state.isSettingsOpen)
        #expect(!state.isHistoryOpen)

        state.openHistory()
        #expect(state.isHistoryOpen)
        #expect(!state.isSettingsOpen)
    }

    @Test
    func openingTheDetailOrTheSettingsClosesTheHistory() throws {
        let store = try sampleStore()
        let priority = try #require(store.openPriorities(in: .today).first)
        let state = PanelState(store: store)
        state.openHistory()
        state.openDetail(priority.id)
        #expect(!state.isHistoryOpen)
        #expect(state.detailPriority?.id == priority.id)

        state.openHistory()
        state.toggleSettings()
        #expect(!state.isHistoryOpen)
        #expect(state.isSettingsOpen)
    }

    @Test
    func aTabChangeAndAScopeChangeCloseTheHistory() throws {
        let state = PanelState(store: try sampleStore())
        state.openHistory()
        state.select(tab: .notes)
        #expect(!state.isHistoryOpen)

        state.openHistory()
        #expect(state.tab == .priorities)
        state.select(scope: .week)
        #expect(!state.isHistoryOpen)
    }

    @Test
    func anAlertThatShowsAPriorityClosesTheHistory() throws {
        let store = try sampleStore()
        let priority = try #require(store.openPriorities(in: .today).first)
        let state = PanelState(store: store)
        state.openHistory()
        state.showInList(priority.id)
        #expect(!state.isHistoryOpen)
        #expect(state.page == .browse)
    }

    @Test
    func theHistoryTheDetailAndTheSettingsNeverShowTogether() throws {
        let store = try sampleStore()
        let priority = try #require(store.openPriorities(in: .today).first)
        let state = PanelState(store: store)
        let steps: [@MainActor () -> Void] = [
            { state.openHistory() },
            { state.openDetail(priority.id) },
            { state.openHistory() },
            { state.openSettings() },
            { state.openHistory() },
            { state.toggleSettings() },
            { state.openDetail(priority.id) },
            { state.select(tab: .notes) },
            { state.openHistory() },
            { state.showInList(priority.id) },
            { state.openHistory() },
            { state.closeHistory() },
            { state.openSettings() },
            { state.closeSettings() },
        ]
        for step in steps {
            step()
            let shown = [state.isHistoryOpen, state.isSettingsOpen, state.detailPriority != nil].filter { $0 }
            #expect(shown.count <= 1)
        }
    }

    @Test
    func theHistoryOpenedFromTheNotesTabShowsThePrioritiesTab() throws {
        let state = PanelState(store: try sampleStore())
        state.select(tab: .notes)
        state.openHistory()
        #expect(state.tab == .priorities)
        #expect(state.isHistoryOpen)
    }

    @Test
    func theHistoryStateIsNotKeptInTheDatabase() throws {
        let store = try sampleStore()
        let before = try values("SELECT key FROM app_state ORDER BY key", in: store.database, as: String.self)
        let state = PanelState(store: store)
        state.openHistory()
        let after = try values("SELECT key FROM app_state ORDER BY key", in: store.database, as: String.self)
        #expect(after == before)
    }

    @Test
    func theHistoryOfTheScopeListShowsOnlyThatList() throws {
        let store = try sampleStore()
        try addDone(store, clock, title: "Week old", list: .week, at: "2026-10-09T09:00:00")
        clock.date = now
        #expect(try store.donePriorities(in: .week, atOrBefore: DoneWindow.cutoff(now: now)).map(\.title) == ["Week old"])
        #expect(try store.donePriorities(in: .today, atOrBefore: DoneWindow.cutoff(now: now)).count == 4)
    }

    @Test
    func theHistoryScrollsAfterThe330PointLimit() throws {
        let store = try makeStore(clock)
        for index in 1...30 {
            try addDone(store, clock, title: "Prioridad vieja \(index)", at: "2026-10-0\(1 + index % 7)T09:\(String(format: "%02d", index)):00")
        }
        clock.date = now
        let state = PanelState(store: store)
        let content = DoneHistoryContent(list: .today, now: now).environment(store).environment(state)
        #expect(NSHostingView(rootView: content.frame(width: 340)).fittingSize.height <= Theme.Row.listMaxHeight)
    }

    @Test
    func theEmptyHistoryShowsALine() throws {
        let store = try makeStore(clock)
        let state = PanelState(store: store)
        let empty = NSHostingView(
            rootView: DoneHistoryContent(list: .today, now: now).environment(store).environment(state).frame(width: 340)
        ).fittingSize.height
        #expect(empty > 0)
        #expect(HistoryCopy.empty == "Nada en el historial.")
    }

    @Test
    func rendersHechasOpenWithTheHistorialRow() throws {
        let store = try sampleStore()
        let state = PanelState(store: store)
        state.toggleDone()
        try render(
            PriorityListView(list: .today).environment(store).environment(state),
            named: "history-hechas-historial-row"
        )
    }

    @Test
    func rendersTheHistoryViewWithTwoDays() throws {
        let store = try sampleStore()
        let state = PanelState(store: store)
        state.openHistory()
        let url = try Screenshot.writeHosted(PanelView().environment(store).environment(state), named: "history-view-two-days")
        #expect(try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) > 0)
    }

    @Test
    func rendersTheEmptyHistoryView() throws {
        let store = try makeStore(clock)
        let state = PanelState(store: store)
        state.openHistory()
        let url = try Screenshot.writeHosted(PanelView().environment(store).environment(state), named: "history-view-empty")
        #expect(try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) > 0)
    }

    @Test
    func rendersTheHistoryViewWithALongList() throws {
        let store = try makeStore(clock)
        for index in 1...12 {
            try addDone(store, clock, title: "Prioridad vieja número \(index)", at: "2026-10-0\(2 + index % 6)T09:\(String(format: "%02d", index)):00")
        }
        clock.date = now
        let state = PanelState(store: store)
        state.openHistory()
        let url = try Screenshot.writeHosted(PanelView().environment(store).environment(state), named: "history-view-long")
        #expect(try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) > 0)
    }
}
