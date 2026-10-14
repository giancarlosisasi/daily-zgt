import Foundation
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct PanelLabelsTests {
    @Test
    func dayLabelNamesTheWeekdayTheDayAndTheMonth() {
        #expect(PanelLabels.date(for: .today, at: localDate("2026-10-12T09:00:00")) == "Lunes 12 oct")
        #expect(PanelLabels.date(for: .today, at: localDate("2026-10-18T23:30:00")) == "Domingo 18 oct")
        #expect(PanelLabels.date(for: .today, at: localDate("2026-12-02T08:00:00")) == "Miércoles 2 dic")
    }

    @Test
    func weekLabelGivesTheIsoWeekAndTheRangeFromMondayToSunday() {
        #expect(PanelLabels.date(for: .week, at: localDate("2026-10-12T09:00:00")) == "Semana 42 · 12–18 oct")
        #expect(PanelLabels.date(for: .week, at: localDate("2026-10-18T23:30:00")) == "Semana 42 · 12–18 oct")
        #expect(PanelLabels.date(for: .week, at: localDate("2026-10-19T00:00:00")) == "Semana 43 · 19–25 oct")
    }

    @Test
    func weekLabelShowsBothMonthsWhenTheWeekCrossesTwo() {
        #expect(PanelLabels.date(for: .week, at: localDate("2026-09-30T10:00:00")) == "Semana 40 · 28 sep–4 oct")
    }

    @Test
    func labelsFollowTheStoreClock() throws {
        let clock = TestClock()
        let store = try makeStore(clock)
        #expect(PanelLabels.date(for: .today, at: store.now()) == "Lunes 12 oct")
        clock.date = localDate("2026-10-13T08:00:00")
        #expect(PanelLabels.date(for: .today, at: store.now()) == "Martes 13 oct")
    }
}
