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

    private func olderIDs(_ store: AppStore, _ filter: DueFilter = .today) throws -> [Priority.ID] {
        store.olderDonePriorities(outside: filter).map(\.id)
    }

    @Test
    func theGroupsFollowTheLocalDayNewestFirst() throws {
        let store = try sampleStore()
        let groups = DoneHistory.groups(from: store.olderDonePriorities(outside: .today, days: DueDays(now: now)))
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
        let groups = DoneHistory.groups(from: store.olderDonePriorities(outside: .today, days: DueDays(now: now)))
        #expect(groups.map(\.day) == ["2026-10-09", "2026-10-08"])
        #expect(groups.map { $0.priorities.map(\.title) } == [["Early"], ["Late"]])
    }

    @Test
    func theGroupsCrossAMonthBoundary() throws {
        let store = try makeStore(clock)
        try addDone(store, clock, title: "October", at: "2026-10-01T09:00:00")
        try addDone(store, clock, title: "September", at: "2026-09-30T09:00:00")
        let groups = DoneHistory.groups(from: store.olderDonePriorities(outside: .today, days: DueDays(now: now)))
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
        let rows = store.olderDonePriorities(outside: .today, days: DueDays(now: now))
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
    func hechasInHoyListsTheDoneOfToday() throws {
        let store = try sampleStore()
        let recent = store.donePriorities(in: .today, days: DueDays(now: now))
        #expect(recent.map(\.title) == ["Llamar al banco"])
        #expect(store.olderDonePriorities(outside: .today, days: DueDays(now: now)).count == 4)
        #expect(store.donePriorities(in: .all, days: DueDays(now: now)).map(\.title) == ["Llamar al banco"])
    }

    @Test
    func aDonePriorityLeavesHechasOfHoyAtMidnightWhileThePanelIsOpen() throws {
        let store = try sampleStore()
        let state = PanelState(store: store)
        state.toggleDone()
        func section(at date: Date) -> some View {
            DoneSectionContent(filter: .today, now: date).environment(store).environment(state)
        }
        let lastMinute = localDate("2026-10-13T23:59:00")
        let midnight = localDate("2026-10-14T00:00:00")
        #expect(height(section(at: midnight)) < height(section(at: lastMinute)))

        #expect(store.donePriorities(in: .today, days: DueDays(now: lastMinute)).map(\.title) == ["Llamar al banco"])
        #expect(store.donePriorities(in: .today, days: DueDays(now: midnight)).isEmpty)
        #expect(store.olderDonePriorities(outside: .today, days: DueDays(now: midnight)).count == 5)
    }

    @Test
    func theHistorialRowShowsOnlyWhenOlderPrioritiesExist() throws {
        let storeWith = try sampleStore()
        let stateWith = PanelState(store: storeWith)
        stateWith.toggleDone()
        let withHistory = height(DoneSectionContent(filter: .today, now: now).environment(storeWith).environment(stateWith))

        let storeWithout = try makeStore(clock)
        try addDone(storeWithout, clock, title: "Llamar al banco", at: "2026-10-13T08:00:00")
        let stateWithout = PanelState(store: storeWithout)
        stateWithout.toggleDone()
        let withoutHistory = height(DoneSectionContent(filter: .today, now: now).environment(storeWithout).environment(stateWithout))

        #expect(withHistory > withoutHistory)
    }

    @Test
    func theHistorialRowIsHiddenWhileHechasIsClosed() throws {
        let store = try sampleStore()
        let state = PanelState(store: store)
        let closed = height(DoneSectionContent(filter: .today, now: now).environment(store).environment(state))
        state.toggleDone()
        let open = height(DoneSectionContent(filter: .today, now: now).environment(store).environment(state))
        #expect(open > closed)
    }

    @Test
    func hechasShowsWhenOnlyOlderPrioritiesExist() throws {
        let store = try makeStore(clock)
        try addDone(store, clock, title: "Old", at: "2026-10-08T09:00:00")
        clock.date = now
        let state = PanelState(store: store)
        let visible = height(DoneSectionContent(filter: .today, now: now).environment(store).environment(state))
        let empty = try makeStore(clock)
        let hidden = height(DoneSectionContent(filter: .today, now: now).environment(empty).environment(PanelState(store: empty)))
        #expect(visible > hidden)
    }

    @Test
    func regresarFromTheHistoryRestoresThePriorityWithTheHighlight() throws {
        let store = try sampleStore()
        let flow = PriorityFlow(store: store, schedule: recorder.schedule)
        let target = try #require(store.snapshot.done.first { $0.title == "Responder a Ana" })
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
        state.select(filter: .week)
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
    func theHistoryShowsTheDoneOutsideTheWindowOfTheFilter() throws {
        let store = try sampleStore()
        try addDone(store, clock, title: "Week old", list: .week, at: "2026-10-09T09:00:00")
        clock.date = now
        #expect(store.olderDonePriorities(outside: .week).map(\.title) == ["Week old", "Pagar el hosting", "Enviar la factura"])
        #expect(store.olderDonePriorities(outside: .today).count == 5)
    }

    @Test
    func theHistoryScrollsAfterThe330PointLimit() throws {
        let store = try makeStore(clock)
        for index in 1...30 {
            try addDone(store, clock, title: "Prioridad vieja \(index)", at: "2026-10-0\(1 + index % 7)T09:\(String(format: "%02d", index)):00")
        }
        clock.date = now
        let state = PanelState(store: store)
        let content = DoneHistoryContent(filter: .today, now: now).environment(store).environment(state)
        #expect(NSHostingView(rootView: content.frame(width: 340)).fittingSize.height <= Theme.Row.listMaxHeight)
    }

    @Test
    func theEmptyHistoryShowsALine() throws {
        let store = try makeStore(clock)
        let state = PanelState(store: store)
        let empty = NSHostingView(
            rootView: DoneHistoryContent(filter: .today, now: now).environment(store).environment(state).frame(width: 340)
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
            PriorityListView(filter: .today).environment(store).environment(state),
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
        try addDone(store, clock, title: Self.longTitle, at: "2026-10-07T10:00:00")
        clock.date = now
        let state = PanelState(store: store)
        state.openHistory()
        let view = PanelView().environment(store).environment(state)
        let url = try Screenshot.writeHosted(view, named: "history-view-long")
        #expect(try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) > 0)
        try expectTitlesWrapInsideTheirFrames(view, longest: Self.longTitle)
    }

    @Test
    func aLongOpenTitleWrapsInsideItsRow() throws {
        let store = try makeStore(clock)
        try store.addPriority(title: Self.longTitle, level: .high, list: .today)
        try store.addPriority(title: "1:1 con el equipo", level: .medium, list: .today)
        clock.date = now
        let state = PanelState(store: store)
        let view = PanelView().environment(store).environment(state)
        let url = try Screenshot.writeHosted(view, named: "list-view-long-title")
        #expect(try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) > 0)
        try expectTitlesWrapInsideTheirFrames(view, longest: Self.longTitle)
    }

    static let longTitle = "Revisar con calma el informe trimestral de ventas, comparar cada número con el del año pasado y escribir un resumen corto para el equipo"

    private func expectTitlesWrapInsideTheirFrames(_ view: some View, longest: String) throws {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
        hosting.layoutSubtreeIfNeeded()
        let titles = Self.titleViews(in: hosting)
        #expect(!titles.isEmpty)
        for title in titles {
            let container = try #require(title.textContainer)
            let layout = try #require(title.layoutManager)
            layout.ensureLayout(for: container)
            #expect(title.clipsToBounds)
            #expect(abs(container.containerSize.width - title.bounds.width) < 0.5, "\(title.string)")
            #expect(layout.usedRect(for: container).width <= title.bounds.width + 0.5, "\(title.string)")
        }
        let long = try #require(titles.first { $0.string == longest })
        #expect(long.bounds.height >= Theme.Font.rowTitleLineHeight * 2)
    }

    private static func titleViews(in view: NSView) -> [ClickableTitleView] {
        view.subviews.flatMap { subview in
            (subview as? ClickableTitleView).map { [$0] } ?? titleViews(in: subview)
        }
    }
}
