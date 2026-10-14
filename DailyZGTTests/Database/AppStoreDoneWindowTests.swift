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

    @Test
    func theCutoffIsExactly24HoursBeforeTheClock() {
        #expect(DoneWindow.cutoff(now: now) == localDate("2026-10-12T10:00:00"))
        #expect(DoneWindow.cutoff(now: now.addingTimeInterval(0.8)) == localDate("2026-10-12T10:00:00"))
    }

    @Test
    func aPriorityDone23Hours59MinutesAgoIsRecent() throws {
        let store = try makeStore(clock)
        let done = try addDone(store, clock, title: "A", at: "2026-10-12T10:01:00")
        let cutoff = DoneWindow.cutoff(now: now)
        #expect(try store.donePriorities(in: .today, after: cutoff).map(\.id) == [done.id])
        #expect(try store.donePriorities(in: .today, atOrBefore: cutoff).isEmpty)
        #expect(try store.doneCount(in: .today, atOrBefore: cutoff) == 0)
    }

    @Test
    func aPriorityDoneExactly24HoursAgoIsOlder() throws {
        let store = try makeStore(clock)
        let done = try addDone(store, clock, title: "A", at: "2026-10-12T10:00:00")
        let cutoff = DoneWindow.cutoff(now: now)
        #expect(try store.donePriorities(in: .today, after: cutoff).isEmpty)
        #expect(try store.donePriorities(in: .today, atOrBefore: cutoff).map(\.id) == [done.id])
        #expect(try store.doneCount(in: .today, atOrBefore: cutoff) == 1)
    }

    @Test
    func aPriorityDone24HoursAndOneMinuteAgoIsOlder() throws {
        let store = try makeStore(clock)
        let done = try addDone(store, clock, title: "A", at: "2026-10-12T09:59:00")
        let cutoff = DoneWindow.cutoff(now: now)
        #expect(try store.donePriorities(in: .today, after: cutoff).isEmpty)
        #expect(try store.donePriorities(in: .today, atOrBefore: cutoff).map(\.id) == [done.id])
    }

    @Test
    func aPriorityLeavesTheRecentSetWhenTheClockPassesItsDay() throws {
        let store = try makeStore(clock)
        let done = try addDone(store, clock, title: "A", at: "2026-10-12T10:00:00")
        let before = DoneWindow.cutoff(now: localDate("2026-10-13T09:59:59"))
        let after = DoneWindow.cutoff(now: localDate("2026-10-13T10:00:00"))
        #expect(try store.donePriorities(in: .today, after: before).map(\.id) == [done.id])
        #expect(try store.donePriorities(in: .today, after: after).isEmpty)
    }

    @Test
    func theQueriesFilterByListAndSkipOpenPriorities() throws {
        let store = try makeStore(clock)
        try addDone(store, clock, title: "Today old", at: "2026-10-10T09:00:00")
        try addDone(store, clock, title: "Week old", list: .week, at: "2026-10-10T09:30:00")
        try addDone(store, clock, title: "Today new", at: "2026-10-13T09:00:00")
        try store.addPriority(title: "Open", list: .today)
        let cutoff = DoneWindow.cutoff(now: now)

        #expect(try store.donePriorities(in: .today, after: cutoff).map(\.title) == ["Today new"])
        #expect(try store.donePriorities(in: .today, atOrBefore: cutoff).map(\.title) == ["Today old"])
        #expect(try store.donePriorities(in: .week, atOrBefore: cutoff).map(\.title) == ["Week old"])
        #expect(try store.donePriorities(in: .week, after: cutoff).isEmpty)
        #expect(try store.doneCount(in: .today, atOrBefore: cutoff) == 1)
        #expect(try store.doneCount(in: .week, atOrBefore: cutoff) == 1)
    }

    @Test
    func theRowsComeNewestFirst() throws {
        let store = try makeStore(clock)
        try addDone(store, clock, title: "First", at: "2026-10-13T08:00:00")
        try addDone(store, clock, title: "Third", at: "2026-10-13T09:30:00")
        try addDone(store, clock, title: "Second", at: "2026-10-13T09:00:00")
        let cutoff = DoneWindow.cutoff(now: now)
        #expect(try store.donePriorities(in: .today, after: cutoff).map(\.title) == ["Third", "Second", "First"])
    }

    @Test
    func olderRowsComeNewestFirst() throws {
        let store = try makeStore(clock)
        try addDone(store, clock, title: "Oldest", at: "2026-10-08T08:00:00")
        try addDone(store, clock, title: "Newest", at: "2026-10-11T08:00:00")
        try addDone(store, clock, title: "Middle", at: "2026-10-10T08:00:00")
        let cutoff = DoneWindow.cutoff(now: now)
        #expect(try store.donePriorities(in: .today, atOrBefore: cutoff).map(\.title) == ["Newest", "Middle", "Oldest"])
    }

    @Test
    func theDoneFromCountIncludesTheStartAndExcludesTheSecondBefore() throws {
        let store = try makeStore(clock)
        try addDone(store, clock, title: "Before", at: "2026-10-12T23:59:59")
        try addDone(store, clock, title: "At the start", at: "2026-10-13T00:00:00")
        try addDone(store, clock, title: "Later", at: "2026-10-13T09:00:00")
        let start = localDate("2026-10-13T00:00:00")
        #expect(try store.doneCount(in: .today, from: start) == 2)
        #expect(try store.doneCount(in: .week, from: start) == 0)
    }

    @Test
    func aQueryAfterAWriteSeesTheNewRow() throws {
        let store = try makeStore(clock)
        let cutoff = DoneWindow.cutoff(now: now)
        #expect(try store.donePriorities(in: .today, after: cutoff).isEmpty)
        try addDone(store, clock, title: "New", at: "2026-10-13T09:00:00")
        #expect(try store.donePriorities(in: .today, after: cutoff).map(\.title) == ["New"])
    }

    @Test
    func theWeekStartIsTheMondayAndTheDayStartIsMidnight() {
        let wednesday = localDate("2026-10-14T15:30:00")
        #expect(DoneWindow.periodStart(for: .today, at: wednesday) == localDate("2026-10-14T00:00:00"))
        #expect(DoneWindow.periodStart(for: .week, at: wednesday) == localDate("2026-10-12T00:00:00"))
        let sunday = localDate("2026-10-18T23:59:59")
        #expect(DoneWindow.periodStart(for: .week, at: sunday) == localDate("2026-10-12T00:00:00"))
        let monday = localDate("2026-10-19T00:00:00")
        #expect(DoneWindow.periodStart(for: .week, at: monday) == localDate("2026-10-19T00:00:00"))
    }
}
