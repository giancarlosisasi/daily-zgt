import Foundation
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct DueCalendarPickTests {
    @Test
    func aMonthArrowOnlyMovesTheShownMonth() {
        let current = localDate("2026-11-17T16:30:00")
        let pick = DuePopoverContent.calendarPick(localDate("2026-12-17T00:00:00"), shown: current, current: current)
        #expect(pick.shown == localDate("2026-12-17T00:00:00"))
        #expect(pick.dueAt == nil)
    }

    @Test
    func aDayClickSavesThatDayAtTheCurrentTime() {
        let current = localDate("2026-11-17T16:30:00")
        let shown = localDate("2026-12-17T00:00:00")
        let pick = DuePopoverContent.calendarPick(localDate("2026-12-05T00:00:00"), shown: shown, current: current)
        #expect(pick.dueAt == localDate("2026-12-05T16:30:00"))
    }
}
