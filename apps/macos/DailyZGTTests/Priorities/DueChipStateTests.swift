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
