import Foundation
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct PanelSummaryTests {
    @Test
    func emptyListsCountZeroOfZero() throws {
        let store = try makeStore()
        #expect(PanelLabels.summary(for: .today, store: store) == "0 de 0 hechas hoy")
        #expect(PanelLabels.summary(for: .week, store: store) == "0 de 0 hechas esta semana")
    }

    @Test
    func summaryCountsDoneOverDoneAndOpenOfTheScopeList() throws {
        let store = try makeStore()
        let first = try store.addPriority(title: "A", list: .today)
        try store.addPriority(title: "B", list: .today)
        try store.addPriority(title: "C", list: .today)
        let weekly = try store.addPriority(title: "D", list: .week)
        try store.addPriority(title: "E", list: .week)
        try store.markDone(first.id)
        #expect(PanelLabels.summary(for: .today, store: store) == "1 de 3 hechas hoy")
        #expect(PanelLabels.summary(for: .week, store: store) == "0 de 2 hechas esta semana")
        try store.markDone(weekly.id)
        #expect(PanelLabels.summary(for: .week, store: store) == "1 de 2 hechas esta semana")
    }

    @Test
    func scopeTabCountsOnlyOpenPriorities() throws {
        let store = try makeStore()
        let first = try store.addPriority(title: "A", list: .today)
        try store.addPriority(title: "B", list: .today)
        try store.markDone(first.id)
        #expect(store.openCount(in: .today) == 1)
    }
}
