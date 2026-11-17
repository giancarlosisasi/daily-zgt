import Foundation
import Testing
@testable import DailyZGT

@MainActor
@discardableResult
func addDone(
    _ store: AppStore,
    _ clock: TestClock,
    title: String,
    list: PriorityList = .today,
    at doneAt: String
) throws -> Priority {
    let added = try store.addPriority(title: title, list: list)
    clock.date = localDate(doneAt)
    return try store.markDone(added.id)
}

@Suite
@MainActor
struct AppStoreDoneWindowTests {
    let clock = TestClock("2026-10-12T08:00:00")
    let now = localDate("2026-10-13T10:00:00")

    private var days: DueDays { DueDays(now: now) }

    @Test
    func theCutoffIsExactly24HoursBeforeTheClock() {
        #expect(DoneWindow.cutoff(now: now) == localDate("2026-10-12T10:00:00"))
        #expect(DoneWindow.cutoff(now: now.addingTimeInterval(0.8)) == localDate("2026-10-12T10:00:00"))
    }

    @Test
    func aPriorityDone23Hours59MinutesAgoIsRecentInTodas() throws {
        let store = try makeStore(clock)
        let done = try addDone(store, clock, title: "A", at: "2026-10-12T10:01:00")
        #expect(store.donePriorities(in: .all, days: days).map(\.id) == [done.id])
        #expect(store.olderDonePriorities(outside: .all, days: days).isEmpty)
    }

    @Test
    func aPriorityDoneExactly24HoursAgoIsOlderInTodas() throws {
        let store = try makeStore(clock)
        let done = try addDone(store, clock, title: "A", at: "2026-10-12T10:00:00")
        #expect(store.donePriorities(in: .all, days: days).isEmpty)
        #expect(store.olderDonePriorities(outside: .all, days: days).map(\.id) == [done.id])
    }

    @Test
    func aPriorityLeavesTheRecentSetWhenTheClockPassesItsDay() throws {
        let store = try makeStore(clock)
        let done = try addDone(store, clock, title: "A", at: "2026-10-12T10:00:00")
        #expect(store.donePriorities(in: .all, days: DueDays(now: localDate("2026-10-13T09:59:59"))).map(\.id) == [done.id])
        #expect(store.donePriorities(in: .all, days: DueDays(now: localDate("2026-10-13T10:00:00"))).isEmpty)
    }

    @Test
    func hoyShowsTheDoneOfTheDayFromMidnight() throws {
        let store = try makeStore(clock)
        try addDone(store, clock, title: "Before", at: "2026-10-12T23:59:59")
        try addDone(store, clock, title: "At the start", at: "2026-10-13T00:00:00")
        try addDone(store, clock, title: "Later", at: "2026-10-13T09:00:00")
        try store.addPriority(title: "Open")
        #expect(store.donePriorities(in: .today, days: days).map(\.title) == ["Later", "At the start"])
        #expect(store.olderDonePriorities(outside: .today, days: days).map(\.title) == ["Before"])
        #expect(store.donePriorities(in: .tomorrow, days: days).isEmpty)
        #expect(store.donePriorities(in: .week, days: days).count == 3)
    }

    @Test
    func theListColumnDoesNotChangeTheDoneWindow() throws {
        let store = try makeStore(clock)
        try addDone(store, clock, title: "Today list", at: "2026-10-13T09:00:00")
        try addDone(store, clock, title: "Week list", list: .week, at: "2026-10-13T09:30:00")
        #expect(store.donePriorities(in: .today, days: days).map(\.title) == ["Week list", "Today list"])
    }

    @Test
    func olderRowsComeNewestFirst() throws {
        let store = try makeStore(clock)
        try addDone(store, clock, title: "Oldest", at: "2026-10-08T08:00:00")
        try addDone(store, clock, title: "Newest", at: "2026-10-11T08:00:00")
        try addDone(store, clock, title: "Middle", at: "2026-10-10T08:00:00")
        #expect(store.olderDonePriorities(outside: .today, days: days).map(\.title) == ["Newest", "Middle", "Oldest"])
    }

    @Test
    func aQueryAfterAWriteSeesTheNewRow() throws {
        let store = try makeStore(clock)
        #expect(store.donePriorities(in: .today, days: days).isEmpty)
        try addDone(store, clock, title: "New", at: "2026-10-13T09:00:00")
        #expect(store.donePriorities(in: .today, days: days).map(\.title) == ["New"])
    }

    @Test
    func theWeekStartIsTheMondayAndTheDayStartIsMidnight() {
        let wednesday = DueDays(now: localDate("2026-10-14T15:30:00"))
        #expect(DueFilter.today.span(wednesday)?.lowerBound == localDate("2026-10-14T00:00:00"))
        #expect(DueFilter.week.span(wednesday)?.lowerBound == localDate("2026-10-12T00:00:00"))
        #expect(DueFilter.week.span(DueDays(now: localDate("2026-10-18T23:59:59")))?.lowerBound == localDate("2026-10-12T00:00:00"))
        #expect(DueFilter.week.span(DueDays(now: localDate("2026-10-19T00:00:00")))?.lowerBound == localDate("2026-10-19T00:00:00"))
    }
}
