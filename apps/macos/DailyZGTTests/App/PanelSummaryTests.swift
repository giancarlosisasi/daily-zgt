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
    func summaryCountsDoneOverDoneAndOpenOfTheFilter() throws {
        let store = try makeStore()
        let today = localDate("2026-10-12T18:00:00")
        let wednesday = localDate("2026-10-14T18:00:00")
        let first = try store.addPriority(title: "A", dueAt: today)
        try store.addPriority(title: "B", dueAt: today)
        try store.addPriority(title: "C", dueAt: today)
        let weekly = try store.addPriority(title: "D", dueAt: wednesday)
        try store.addPriority(title: "E", dueAt: wednesday)
        try store.addPriority(title: "F")
        try store.markDone(first.id)
        #expect(PanelLabels.summary(for: .today, store: store) == "1 de 3 hechas hoy")
        #expect(PanelLabels.summary(for: .week, store: store) == "1 de 5 hechas esta semana")
        #expect(PanelLabels.summary(for: .day("2026-10-14"), store: store) == "0 de 2 hechas el miércoles 14")
        #expect(PanelLabels.summary(for: .all, store: store) == "1 de 6 hechas en 24 h")
        try store.markDone(weekly.id)
        #expect(PanelLabels.summary(for: .week, store: store) == "2 de 5 hechas esta semana")
    }

    @Test
    func theCountOfAFilterCountsOnlyOpenPriorities() throws {
        let store = try makeStore()
        let first = try store.addPriority(title: "A", dueAt: localDate("2026-10-12T18:00:00"))
        try store.addPriority(title: "B", dueAt: localDate("2026-10-12T18:00:00"))
        try store.markDone(first.id)
        #expect(store.openCount(in: .today) == 1)
    }
}
