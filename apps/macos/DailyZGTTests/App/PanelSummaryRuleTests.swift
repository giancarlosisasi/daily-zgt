import Foundation
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct PanelSummaryRuleTests {
    let clock = TestClock("2026-10-05T08:00:00")

    @Test
    func theDayCountStartsAtLocalMidnight() throws {
        let store = try makeStore(clock)
        try addDone(store, clock, title: "Before", at: "2026-10-12T23:59:59")
        try addDone(store, clock, title: "At midnight", at: "2026-10-13T00:00:00")
        try addDone(store, clock, title: "Morning", at: "2026-10-13T08:00:00")
        try store.addPriority(title: "Open", list: .today)
        clock.date = localDate("2026-10-13T09:00:00")
        #expect(PanelLabels.summary(for: .today, store: store) == "2 de 3 hechas hoy")
    }

    @Test
    func aDayChangeMovesTheDonePrioritiesOutOfTheCount() throws {
        let store = try makeStore(clock)
        try addDone(store, clock, title: "Morning", at: "2026-10-12T08:00:00")
        try store.addPriority(title: "Open", list: .today)
        clock.date = localDate("2026-10-12T23:59:59")
        #expect(PanelLabels.summary(for: .today, store: store) == "1 de 2 hechas hoy")
        clock.date = localDate("2026-10-13T00:00:00")
        #expect(PanelLabels.summary(for: .today, store: store) == "0 de 1 hechas hoy")
    }

    @Test
    func theWeekCountStartsOnTheIsoMonday() throws {
        let store = try makeStore(clock)
        try addDone(store, clock, title: "Sunday", list: .week, at: "2026-10-11T23:59:59")
        try addDone(store, clock, title: "Monday", list: .week, at: "2026-10-12T00:00:00")
        try addDone(store, clock, title: "Friday", list: .week, at: "2026-10-16T12:00:00")
        try store.addPriority(title: "Open", list: .week)
        clock.date = localDate("2026-10-17T09:00:00")
        #expect(PanelLabels.summary(for: .week, store: store) == "2 de 3 hechas esta semana")
    }

    @Test
    func theWeekCountEndsAtTheSundayNight() throws {
        let store = try makeStore(clock)
        try addDone(store, clock, title: "Monday", list: .week, at: "2026-10-12T09:00:00")
        clock.date = localDate("2026-10-18T23:59:59")
        #expect(PanelLabels.summary(for: .week, store: store) == "1 de 1 hechas esta semana")
        clock.date = localDate("2026-10-19T00:00:00")
        #expect(PanelLabels.summary(for: .week, store: store) == "0 de 0 hechas esta semana")
    }

    @Test
    func theWeekCountCrossesAMonthBoundary() throws {
        let store = try makeStore(clock)
        try addDone(store, clock, title: "Tuesday", list: .week, at: "2026-09-29T10:00:00")
        try addDone(store, clock, title: "Previous Sunday", list: .week, at: "2026-09-27T10:00:00")
        clock.date = localDate("2026-10-02T09:00:00")
        #expect(PanelLabels.summary(for: .week, store: store) == "1 de 1 hechas esta semana")
    }

    @Test
    func theCountDoesNotGrowWithTheHistory() throws {
        let store = try makeStore(clock)
        for day in 1...9 {
            try addDone(store, clock, title: "Old \(day)", at: "2026-10-0\(day)T09:00:00")
        }
        try addDone(store, clock, title: "Today", at: "2026-10-13T08:00:00")
        try store.addPriority(title: "Open", list: .today)
        clock.date = localDate("2026-10-13T09:00:00")
        #expect(PanelLabels.summary(for: .today, store: store) == "1 de 2 hechas hoy")
    }

    @Test
    func theCountOfHoyAndOfSemanaAreIndependent() throws {
        let store = try makeStore(clock)
        try addDone(store, clock, title: "Today", at: "2026-10-13T08:00:00")
        try addDone(store, clock, title: "Week", list: .week, at: "2026-10-13T08:30:00")
        try addDone(store, clock, title: "Week again", list: .week, at: "2026-10-13T08:40:00")
        try store.addPriority(title: "Open week", list: .week)
        clock.date = localDate("2026-10-13T09:00:00")
        #expect(PanelLabels.summary(for: .today, store: store) == "1 de 1 hechas hoy")
        #expect(PanelLabels.summary(for: .week, store: store) == "2 de 3 hechas esta semana")
    }

    @Test
    func theSummaryUsesTheClockThatTheFooterPasses() throws {
        let store = try makeStore(clock)
        try addDone(store, clock, title: "Morning", at: "2026-10-12T08:00:00")
        clock.date = localDate("2026-10-12T09:00:00")
        #expect(PanelLabels.summary(for: .today, store: store) == "1 de 1 hechas hoy")
        #expect(PanelLabels.summary(for: .today, store: store, now: localDate("2026-10-13T09:00:00")) == "0 de 0 hechas hoy")
    }

    @Test
    func theEmptyListsStillCountZeroOfZero() throws {
        let store = try makeStore(clock)
        #expect(PanelLabels.summary(for: .today, store: store) == "0 de 0 hechas hoy")
        #expect(PanelLabels.summary(for: .week, store: store) == "0 de 0 hechas esta semana")
    }
}
