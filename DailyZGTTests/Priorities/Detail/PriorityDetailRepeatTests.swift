import AppKit
import Foundation
import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct PriorityDetailRepeatTests {
    let clock = TestClock("2026-10-12T10:24:00")

    private func setup() throws -> (AppStore, Priority, PriorityDetailActions) {
        let store = try makeStore(clock)
        let priority = try store.addPriority(
            title: "Meditar",
            level: .medium,
            list: .today,
            dueAt: localDate("2026-10-12T18:30:00"),
            note: "Diez minutos."
        )
        return (store, priority, PriorityDetailActions(store: store, id: priority.id))
    }

    private func box(_ priority: Priority) -> PriorityDetailBox {
        PriorityDetailBox(priority: priority, now: clock.date, onLevel: { _ in }, onDue: { _ in }, onList: { _ in })
    }

    @Test
    func theChoicesAreNoAndCadaDia() {
        #expect(RepeatRule.allCases.map(\.title) == ["No", "Cada día"])
    }

    @Test
    func theRepeatChoiceSavesAtOnceAndWritesAnEditedEvent() throws {
        let (store, priority, actions) = try setup()
        #expect(store.priority(id: priority.id)?.repeatRule == RepeatRule.none)
        clock.advance(minutes: 5)

        try actions.setRepeat(.daily)

        #expect(store.priority(id: priority.id)?.repeatRule == .daily)
        #expect(try values("SELECT repeat_rule FROM priority", in: store.database, as: String.self) == ["daily"])
        #expect(try store.events(of: priority.id).map(\.type) == [.created, .edited])
        #expect(store.priority(id: priority.id)?.updatedAt == localDate("2026-10-12T10:29:00"))

        try actions.setRepeat(.daily)
        #expect(try store.events(of: priority.id).map(\.type) == [.created, .edited])

        try actions.setRepeat(.none)
        #expect(try values("SELECT repeat_rule FROM priority", in: store.database, as: String.self) == ["none"])
        #expect(try store.events(of: priority.id).map(\.type) == [.created, .edited, .edited])
    }

    @Test
    func theRepeatChoiceDoesNotTouchTheOtherFields() throws {
        let (store, priority, actions) = try setup()

        try actions.setRepeat(.daily)

        var expected = priority
        expected.repeatRule = .daily
        expected.updatedAt = clock.date
        #expect(store.priority(id: priority.id) == expected)
        #expect(store.openPriorities(in: .today).map(\.id) == [priority.id])
        #expect(try store.alerts().isEmpty)
    }

    @Test
    func theRepeatChoiceOnAMissingPriorityThrows() throws {
        let store = try makeStore(clock)
        let actions = PriorityDetailActions(store: store, id: "missing")
        #expect(throws: AppStoreError.priorityNotFound("missing")) {
            try actions.setRepeat(.daily)
        }
    }

    @Test
    func theBoxHasTheSameHeightWithEachChoice() throws {
        let (store, priority, actions) = try setup()
        try actions.setRepeat(.daily)
        let daily = try #require(store.priority(id: priority.id))
        let width = Theme.Panel.width
        let noneHeight = NSHostingView(rootView: box(priority).frame(width: width)).fittingSize.height
        let dailyHeight = NSHostingView(rootView: box(daily).frame(width: width)).fittingSize.height
        #expect(noneHeight == dailyHeight)
    }

    @Test(arguments: [RepeatRule.none, .daily])
    func rendersTheDetailWithTheRepeatRow(rule: RepeatRule) throws {
        let (store, priority, actions) = try setup()
        try actions.setRepeat(rule)
        let shown = try #require(store.priority(id: priority.id))
        let state = PanelState(store: store)
        let url = try Screenshot.writeHosted(
            PriorityDetailView(priority: shown).environment(store).environment(state).panelChrome(),
            named: "detail-repeat-\(rule.rawValue)"
        )
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }
}
