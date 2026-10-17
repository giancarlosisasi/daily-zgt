import AppKit
import Foundation
import GRDB
import SwiftUI
import Testing
@testable import DailyZGT

final class StatementLog: @unchecked Sendable {
    private let lock = NSLock()
    private var statements: [String] = []

    func add(_ statement: String) {
        lock.lock()
        statements.append(statement)
        lock.unlock()
    }

    var all: [String] {
        lock.lock()
        defer { lock.unlock() }
        return statements
    }
}

@Suite
@MainActor
struct TodayEntryTests {
    let clock = TestClock("2026-10-05T09:00:00")

    private func event(_ type: PriorityEventType, _ at: String) -> PriorityEvent {
        PriorityEvent(id: nil, priorityID: "p", at: localDate(at), type: type)
    }

    private func label(entered: String, now: String) -> String? {
        TodayEntry.chip(enteredAt: localDate(entered), now: localDate(now))?.label
    }

    @Test
    func theEntryIsTheCreatedEventWhenThereIsNoMove() {
        let events = [event(.created, "2026-10-09T10:00:00"), event(.edited, "2026-10-10T10:00:00")]
        #expect(TodayEntry.enteredAt(events: events) == localDate("2026-10-09T10:00:00"))
    }

    @Test
    func theEntryIsTheLastMovedEvent() {
        let events = [
            event(.created, "2026-10-05T10:00:00"),
            event(.moved, "2026-10-06T10:00:00"),
            event(.edited, "2026-10-08T10:00:00"),
            event(.moved, "2026-10-07T10:00:00"),
            event(.done, "2026-10-09T10:00:00"),
        ]
        #expect(TodayEntry.enteredAt(events: events) == localDate("2026-10-07T10:00:00"))
    }

    @Test
    func theEntryIgnoresEveryOtherEventType() {
        let events = [
            event(.created, "2026-10-05T10:00:00"),
            event(.edited, "2026-10-09T10:00:00"),
            event(.subtaskDone, "2026-10-09T11:00:00"),
            event(.done, "2026-10-09T12:00:00"),
            event(.restored, "2026-10-12T09:00:00"),
        ]
        #expect(TodayEntry.enteredAt(events: events) == localDate("2026-10-05T10:00:00"))
    }

    @Test
    func noEventsGiveNoEntryAndNoChip() {
        #expect(TodayEntry.enteredAt(events: []) == nil)
        #expect(TodayEntry.chip(events: [], now: localDate("2026-10-12T09:00:00")) == nil)
        #expect(TodayEntry.chip(enteredAt: nil, now: localDate("2026-10-12T09:00:00")) == nil)
    }

    @Test
    func noChipOnTheDayOfTheEntry() {
        #expect(label(entered: "2026-10-12T00:00:00", now: "2026-10-12T09:00:00") == nil)
        #expect(label(entered: "2026-10-12T08:59:00", now: "2026-10-12T23:59:59") == nil)
    }

    @Test
    func deAyerForTheDayBefore() {
        #expect(label(entered: "2026-10-11T08:00:00", now: "2026-10-12T09:00:00") == "De ayer")
        #expect(label(entered: "2026-10-11T23:59:59", now: "2026-10-12T00:00:00") == "De ayer")
        #expect(label(entered: "2026-10-11T00:00:00", now: "2026-10-11T23:59:59") == nil)
    }

    @Test
    func desdeWithTheWeekdayAndTheDayForOlderEntries() {
        #expect(label(entered: "2026-10-09T10:00:00", now: "2026-10-12T09:00:00") == "Desde vie 9")
        #expect(label(entered: "2026-10-10T10:00:00", now: "2026-10-12T09:00:00") == "Desde sáb 10")
        #expect(label(entered: "2026-10-04T10:00:00", now: "2026-10-12T09:00:00") == "Desde dom 4")
        #expect(label(entered: "2026-10-05T10:00:00", now: "2026-10-12T09:00:00") == "Desde lun 5")
        #expect(label(entered: "2026-10-07T10:00:00", now: "2026-10-12T09:00:00") == "Desde mié 7")
        #expect(label(entered: "2026-10-06T10:00:00", now: "2026-10-12T09:00:00") == "Desde mar 6")
        #expect(label(entered: "2026-10-08T10:00:00", now: "2026-10-12T09:00:00") == "Desde jue 8")
    }

    @Test
    func theMonthBoundary() {
        #expect(label(entered: "2026-09-30T10:00:00", now: "2026-10-01T09:00:00") == "De ayer")
        #expect(label(entered: "2026-09-30T10:00:00", now: "2026-10-02T09:00:00") == "Desde mié 30")
        #expect(label(entered: "2026-09-28T10:00:00", now: "2026-10-12T09:00:00") == "Desde lun 28")
    }

    @Test
    func theYearBoundary() {
        #expect(label(entered: "2025-12-31T10:00:00", now: "2026-01-01T09:00:00") == "De ayer")
        #expect(label(entered: "2025-12-31T10:00:00", now: "2026-01-02T09:00:00") == "Desde mié 31")
    }

    @Test
    func anEntryInTheFutureGivesNoChip() {
        #expect(label(entered: "2026-10-13T10:00:00", now: "2026-10-12T09:00:00") == nil)
    }

    @Test
    func theChipUsesTheCalmLaterTone() throws {
        let chip = try #require(TodayEntry.chip(enteredAt: localDate("2026-10-09T10:00:00"), now: localDate("2026-10-12T09:00:00")))
        #expect(chip.tone == .later)
        let yesterday = try #require(TodayEntry.chip(enteredAt: localDate("2026-10-11T10:00:00"), now: localDate("2026-10-12T09:00:00")))
        #expect(yesterday.tone == .later)
    }

    @Test
    func aPriorityMadeInHoyTakesTheDateOfItsCreation() throws {
        let store = try makeStore(clock)
        clock.date = localDate("2026-10-09T10:00:00")
        let made = try store.addPriority(title: "A", list: .today)
        let events = try store.events(of: made.id)
        #expect(TodayEntry.chip(events: events, now: localDate("2026-10-09T18:00:00")) == nil)
        #expect(TodayEntry.chip(events: events, now: localDate("2026-10-10T08:00:00"))?.label == "De ayer")
        #expect(TodayEntry.chip(events: events, now: localDate("2026-10-12T08:00:00"))?.label == "Desde vie 9")
    }

    @Test
    func aPriorityMovedToHoyTakesTheDateOfTheMove() throws {
        let store = try makeStore(clock)
        let made = try store.addPriority(title: "A", list: .week)
        clock.date = localDate("2026-10-07T10:00:00")
        try store.movePriority(made.id, to: .today)
        let events = try store.events(of: made.id)
        #expect(events.map(\.type) == [.created, .moved])
        #expect(TodayEntry.chip(events: events, now: localDate("2026-10-07T20:00:00")) == nil)
        #expect(TodayEntry.chip(events: events, now: localDate("2026-10-09T08:00:00"))?.label == "Desde mié 7")
    }

    @Test
    func aPriorityMovedAwayAndBackTakesTheDateOfTheLastMove() throws {
        let store = try makeStore(clock)
        let made = try store.addPriority(title: "A", list: .today)
        clock.date = localDate("2026-10-06T10:00:00")
        try store.movePriority(made.id, to: .week)
        clock.date = localDate("2026-10-08T10:00:00")
        try store.movePriority(made.id, to: .today)
        let events = try store.events(of: made.id)
        #expect(TodayEntry.chip(events: events, now: localDate("2026-10-09T08:00:00"))?.label == "De ayer")
        #expect(TodayEntry.chip(events: events, now: localDate("2026-10-12T08:00:00"))?.label == "Desde jue 8")
    }

    @Test
    func anEditOrASubtaskDoesNotChangeTheEntry() throws {
        let store = try makeStore(clock)
        let made = try store.addPriority(title: "A", list: .today)
        clock.date = localDate("2026-10-08T10:00:00")
        try store.editPriority(made.id) { $0.title = "B" }
        try store.addSubtask(to: made.id, title: "S")
        clock.date = localDate("2026-10-12T08:00:00")
        let events = try store.events(of: made.id)
        #expect(TodayEntry.chip(events: events, now: clock.date)?.label == "Desde lun 5")
    }

    @Test
    func aRestoredPriorityKeepsTheDateOfItsEntry() throws {
        let store = try makeStore(clock)
        let made = try store.addPriority(title: "A", list: .today)
        try store.markDone(made.id)
        clock.date = localDate("2026-10-09T10:00:00")
        try store.restorePriority(made.id)
        let events = try store.events(of: made.id)
        #expect(TodayEntry.chip(events: events, now: clock.date)?.label == "Desde lun 5")
    }

    @Test
    func aDailyCopyIsMadeTodayAndHasNoChip() throws {
        let store = try makeStore(clock)
        let daily = try addDaily(store, title: "Meditar")
        try store.markDone(daily.id)
        clock.date = localDate("2026-10-06T07:00:00")
        let copy = try #require(try store.addRepeatCopies().first)
        let events = try store.events(of: copy.id)
        #expect(events.map(\.type) == [.created])
        #expect(TodayEntry.chip(events: events, now: localDate("2026-10-06T20:00:00")) == nil)
        #expect(TodayEntry.chip(events: events, now: localDate("2026-10-07T08:00:00"))?.label == "De ayer")
    }

    @Test
    func anOpenPriorityOfHoyStaysInHoyWhenTheDayChanges() throws {
        let store = try makeStore(clock)
        clock.date = localDate("2026-10-12T21:00:00")
        let made = try store.addPriority(title: "Sigue en Hoy", list: .today)
        for next in ["2026-10-12T23:59:59", "2026-10-13T00:00:00", "2026-10-13T09:00:00", "2026-10-20T09:00:00"] {
            clock.date = localDate(next)
            #expect(store.openPriorities(in: .today).map(\.id) == [made.id])
            #expect(store.openPriorities(in: .week).isEmpty)
            #expect(store.openCount(in: .today) == 1)
        }
        #expect(store.priority(id: made.id)?.list == .today)
    }

    @Test
    func theChipsOfAListFollowADayChange() throws {
        let store = try makeStore(clock)
        clock.date = localDate("2026-10-12T21:00:00")
        let made = try store.addPriority(title: "A", list: .today)
        let events = TodayEntry.events(for: .today, in: store)
        #expect(TodayEntry.chips(events: events, now: localDate("2026-10-12T23:59:00"))[made.id] == nil)
        #expect(TodayEntry.chips(events: events, now: localDate("2026-10-13T00:00:00"))[made.id]?.label == "De ayer")
        #expect(TodayEntry.chips(events: events, now: localDate("2026-10-15T00:00:00"))[made.id]?.label == "Desde lun 12")
    }

    @Test
    func theEventsOfTheListComeFromOneQueryForAllTheRows() throws {
        let store = try makeStore(clock)
        for index in 1...8 {
            try store.addPriority(title: "Prioridad \(index)", list: .today)
        }
        let log = StatementLog()
        try store.database.write { database in
            database.trace { log.add($0.description) }
        }

        let events = try store.enteringEvents(in: .today)

        let queries = log.all.filter { $0.contains("priority_event") }
        #expect(events.count == 8)
        #expect(queries.count == 1)
        try store.database.write { $0.trace(nil) }
    }

    @Test
    func theEventsOfTheListCoverOnlyOpenRowsOfThatList() throws {
        let store = try makeStore(clock)
        let open = try store.addPriority(title: "Open", list: .today)
        let done = try store.addPriority(title: "Done", list: .today)
        let weekly = try store.addPriority(title: "Week", list: .week)
        try store.markDone(done.id)
        let today = try store.enteringEvents(in: .today)
        #expect(Set(today.keys) == [open.id])
        #expect(try store.enteringEvents(in: .week).keys.contains(weekly.id))
        #expect(TodayEntry.events(for: .week, in: store).isEmpty)
    }

    @Test
    func theEventsOfTheListKeepOnlyCreatedAndMoved() throws {
        let store = try makeStore(clock)
        let made = try store.addPriority(title: "A", list: .week)
        try store.movePriority(made.id, to: .today)
        try store.editPriority(made.id) { $0.title = "B" }
        try store.addSubtask(to: made.id, title: "S")
        let types = try #require(try store.enteringEvents(in: .today)[made.id]).map(\.type)
        #expect(types == [.created, .moved])
    }

    private func sampleStore() throws -> AppStore {
        let store = try makeStore(clock)
        clock.date = localDate("2026-10-09T09:00:00")
        try store.addPriority(title: "Preparar la demo del viernes", level: .high, list: .today, dueAt: localDate("2026-10-12T16:00:00"))
        try store.addPriority(title: "Del viernes pasado en Semana", level: .low, list: .week)
        clock.date = localDate("2026-10-11T09:00:00")
        try store.addPriority(title: "Revisar el contrato de Lima", level: .medium, list: .today, dueAt: localDate("2026-10-12T11:00:00"))
        clock.date = localDate("2026-10-12T09:00:00")
        try store.addPriority(title: "Ordenar el escritorio", level: .low, list: .today)
        clock.date = localDate("2026-10-12T10:24:00")
        return store
    }

    private func render(_ view: some View, named name: String) throws {
        let url = try Screenshot.writeHosted(view.panelChrome(), named: name)
        #expect(try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) > 0)
    }

    @Test
    func rendersAListWithNoChipDeAyerAndDesde() throws {
        let store = try sampleStore()
        let state = PanelState(store: store)
        try render(PriorityListView(list: .today).environment(store).environment(state), named: "today-entry-list")
    }

    @Test
    func rendersThePanelWithTheChips() throws {
        let store = try sampleStore()
        let state = PanelState(store: store)
        let url = try Screenshot.writeHosted(PanelView().environment(store).environment(state), named: "today-entry-panel")
        #expect(try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) > 0)
    }

    @Test
    func theSemanaListShowsNoChip() throws {
        let store = try sampleStore()
        let state = PanelState(store: store)
        state.select(scope: .week)
        let url = try Screenshot.writeHosted(PanelView().environment(store).environment(state), named: "today-entry-week")
        #expect(try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) > 0)
    }

    private func row(due: String?, entered: String?, subtasks: Bool, note: String) -> some View {
        let priority = Priority(
            id: "r",
            title: "Terminar el brief de Tailwind v4",
            note: note,
            level: .high,
            list: .today,
            dueAt: due.map(localDate),
            doneAt: nil,
            position: 1,
            createdAt: clock.date,
            updatedAt: clock.date
        )
        return PriorityRow(
            priority: priority,
            progress: subtasks ? SubtaskProgress(done: 1, total: 3) : SubtaskProgress(done: 0, total: 0),
            now: localDate("2026-10-12T10:24:00"),
            todayChip: TodayEntry.chip(enteredAt: entered.map(localDate), now: localDate("2026-10-12T10:24:00"))
        )
    }

    private func height(_ view: some View) -> CGFloat {
        NSHostingView(rootView: view.panelChrome()).fittingSize.height
    }

    @Test
    func theMetaLineDoesNotWrapWithTheDueTheSubtasksTheNoteAndTheChip() throws {
        let widest = [
            ("2026-10-12T11:44:00", "2026-09-30T09:00:00"),
            ("2026-10-12T11:44:00", "2026-10-07T09:00:00"),
            ("2026-10-12T16:00:00", "2026-10-11T09:00:00"),
            ("2026-10-12T09:00:00", "2026-10-07T09:00:00"),
            ("2026-10-16T10:00:00", "2026-10-07T09:00:00"),
        ]
        for (due, entered) in widest {
            let withChip = height(row(due: due, entered: entered, subtasks: true, note: "Doc."))
            let without = height(row(due: due, entered: nil, subtasks: true, note: "Doc."))
            #expect(withChip == without)
        }
    }

    @Test
    func theMetaLineWithEverythingFitsInTheRow() throws {
        let line = row(due: "2026-10-12T11:44:00", entered: "2026-09-30T09:00:00", subtasks: true, note: "Doc.")
        let url = try Screenshot.writeHosted(line.panelChrome(), named: "today-entry-row-full-meta")
        #expect(try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) > 0)
    }

    @Test
    func rendersTheDetailWithTheChip() throws {
        let store = try sampleStore()
        let state = PanelState(store: store)
        let priority = try #require(store.openPriorities(in: .today).first { $0.title == "Preparar la demo del viernes" })
        let view = PriorityDetailView(priority: priority).environment(store).environment(state)
        let url = try Screenshot.writeHosted(view.panelChrome(), named: "today-entry-detail")
        #expect(try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) > 0)
    }

    @Test
    func rendersTheDetailChipLineAlone() throws {
        let store = try sampleStore()
        let priority = try #require(store.openPriorities(in: .today).first { $0.title == "Preparar la demo del viernes" })
        let chips = PriorityDetailChips(
            priority: priority,
            progress: SubtaskProgress(done: 1, total: 3),
            now: clock.date,
            todayChip: TodayEntry.chip(events: try store.events(of: priority.id), now: clock.date)
        )
        try render(chips, named: "today-entry-detail-chips")
        let plain = PriorityDetailChips(priority: priority, progress: SubtaskProgress(done: 1, total: 3), now: clock.date)
        #expect(height(chips) == height(plain))
    }
}
