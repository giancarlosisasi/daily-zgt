import Foundation
import Testing
@testable import DailyZGT

@Suite
struct DueChipStateTests {
    let now = localDate("2026-10-12T10:24:00")

    private func chip(minutes: Int, seconds: Int = 0) -> DueChipState? {
        DueChipState.make(due: now.addingTimeInterval(TimeInterval(minutes * 60 + seconds)), now: now)
    }

    @Test
    func noDueGivesNoChip() {
        #expect(DueChipState.make(due: nil, now: now) == nil)
    }

    @Test
    func pastDueIsOverdue() {
        #expect(chip(minutes: -1) == DueChipState(label: "Vencida", tone: .overdue))
        #expect(chip(minutes: -600) == DueChipState(label: "Vencida", tone: .overdue))
    }

    @Test
    func theDueTimeItselfIsZeroMinutes() {
        #expect(chip(minutes: 0) == DueChipState(label: "En 0 min", tone: .soon))
    }

    @Test
    func oneMinuteShowsMinutes() {
        #expect(chip(minutes: 1) == DueChipState(label: "En 1 min", tone: .soon))
    }

    @Test
    func thirtySixMinutesShowsMinutes() {
        #expect(chip(minutes: 36) == DueChipState(label: "En 36 min", tone: .soon))
    }

    @Test
    func fiftyNineMinutesStillShowsOnlyMinutes() {
        #expect(chip(minutes: 59) == DueChipState(label: "En 59 min", tone: .soon))
    }

    @Test
    func sixtyMinutesSwitchesToHoursAndMinutes() {
        #expect(chip(minutes: 60) == DueChipState(label: "En 1 h 0 min", tone: .soon))
    }

    @Test
    func eightyMinutesShowsHoursAndMinutes() {
        #expect(chip(minutes: 80) == DueChipState(label: "En 1 h 20 min", tone: .soon))
    }

    @Test
    func oneHundredNineteenMinutesIsStillSoon() {
        #expect(chip(minutes: 119) == DueChipState(label: "En 1 h 59 min", tone: .soon))
    }

    @Test
    func oneHundredTwentyMinutesIsNoLongerSoon() {
        #expect(chip(minutes: 120) == DueChipState(label: "Hoy 12:24", tone: .later))
    }

    @Test
    func laterTodayShowsTheTime() {
        let due = localDate("2026-10-12T16:00:00")
        #expect(DueChipState.make(due: due, now: now) == DueChipState(label: "Hoy 16:00", tone: .later))
    }

    @Test
    func anotherDayShowsTheWeekday() {
        let friday = localDate("2026-10-16T18:00:00")
        #expect(DueChipState.make(due: friday, now: now) == DueChipState(label: "vie 18:00", tone: .later))
        let sunday = localDate("2026-10-18T09:05:00")
        #expect(DueChipState.make(due: sunday, now: now) == DueChipState(label: "dom 09:05", tone: .later))
        let wednesday = localDate("2026-10-14T08:00:00")
        #expect(DueChipState.make(due: wednesday, now: now) == DueChipState(label: "mié 08:00", tone: .later))
    }

    @Test
    func tomorrowAfterMidnightIsAnotherDay() {
        let lateNow = localDate("2026-10-12T21:30:00")
        let due = localDate("2026-10-13T00:30:00")
        #expect(DueChipState.make(due: due, now: lateNow) == DueChipState(label: "mar 00:30", tone: .later))
    }

    @Test
    func halfAMinuteRoundsToTheNearestMinute() {
        #expect(chip(minutes: 0, seconds: -29) == DueChipState(label: "En 0 min", tone: .soon))
        #expect(chip(minutes: 0, seconds: -31) == DueChipState(label: "Vencida", tone: .overdue))
        #expect(chip(minutes: 0, seconds: 30) == DueChipState(label: "En 1 min", tone: .soon))
    }
}

@Suite
struct DueChipDayTests {
    let now = localDate("2026-11-17T10:24:00")

    @Test
    func aRowUnderADayHeaderShowsOnlyTheTime() {
        #expect(DueChipState.make(due: localDate("2026-11-17T17:00:00"), now: now, showsDay: false) == DueChipState(label: "17:00", tone: .later))
        #expect(DueChipState.make(due: localDate("2026-11-18T09:00:00"), now: now, showsDay: false) == DueChipState(label: "09:00", tone: .later))
        #expect(DueChipState.make(due: localDate("2026-11-17T17:00:00"), now: now) == DueChipState(label: "Hoy 17:00", tone: .later))
    }

    @Test
    func theAlertChipsStayUnderADayHeader() {
        #expect(DueChipState.make(due: localDate("2026-11-17T09:00:00"), now: now, showsDay: false) == DueChipState(label: "Vencida", tone: .overdue))
        #expect(DueChipState.make(due: localDate("2026-11-17T11:00:00"), now: now, showsDay: false) == DueChipState(label: "En 36 min", tone: .soon))
    }

    @Test
    func theGroupsThatNameADayAreMarked() {
        let days = DueDays(now: now)
        let open = [
            Priority(id: "late", title: "a", note: "", level: .high, list: .today, dueAt: localDate("2026-11-16T09:00:00"), doneAt: nil, position: 1, createdAt: now, updatedAt: now),
            Priority(id: "today", title: "b", note: "", level: .high, list: .today, dueAt: localDate("2026-11-17T17:00:00"), doneAt: nil, position: 2, createdAt: now, updatedAt: now),
            Priority(id: "next", title: "c", note: "", level: .high, list: .today, dueAt: localDate("2026-11-18T09:00:00"), doneAt: nil, position: 3, createdAt: now, updatedAt: now),
            Priority(id: "none", title: "d", note: "", level: .high, list: .today, dueAt: nil, doneAt: nil, position: 4, createdAt: now, updatedAt: now),
        ]
        let today = DueFilter.today.groups(open, days)
        #expect(today.map(\.id) == ["overdue", "today", "noDate"])
        #expect(today.map(\.namesDay) == [false, true, false])
        #expect(DueFilter.all.groups(open, days).map(\.namesDay) == [false, true, true, false])
        #expect(DueFilter.week.groups(open, days).allSatisfy { $0.namesDay })
        #expect(DueFilter.tomorrow.groups(open, days).map(\.namesDay) == [true])
        #expect(DueFilter.noDate.groups(open, days).map(\.namesDay) == [false])
    }
}
