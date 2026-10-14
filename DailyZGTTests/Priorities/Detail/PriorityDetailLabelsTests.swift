import Foundation
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct PriorityDetailLabelsTests {
    private let now = localDate("2026-10-12T10:24:00")

    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    @Test
    func aPriorityCreatedTodayShowsCreadaHoy() {
        let created = localDate("2026-10-12T08:05:00")
        #expect(PriorityDetailLabels.created(created, now: now, calendar: calendar()) == "Creada hoy")
    }

    @Test
    func aPriorityCreatedEarlierShowsTheDayAndTheTime() {
        let created = localDate("2026-10-09T17:20:00")
        #expect(PriorityDetailLabels.created(created, now: now, calendar: calendar()) == "Creada vie 9 oct · 17:20")
    }

    @Test
    func theTimeHasLeadingZeros() {
        let created = localDate("2026-09-27T00:05:00")
        #expect(PriorityDetailLabels.created(created, now: now, calendar: calendar()) == "Creada dom 27 sep · 00:05")
    }

    @Test
    func justAfterMidnightIsAnotherDay() {
        let late = localDate("2026-10-11T23:59:00")
        let early = localDate("2026-10-12T00:01:00")
        #expect(PriorityDetailLabels.created(late, now: now, calendar: calendar()) == "Creada dom 11 oct · 23:59")
        #expect(PriorityDetailLabels.created(early, now: now, calendar: calendar()) == "Creada hoy")
    }

    @Test
    func theAlertTextFollowsTheDue() {
        #expect(PriorityDetailLabels.alert(due: now) == "30 min antes y al vencer")
        #expect(PriorityDetailLabels.alert(due: nil) == "Sin fecha, sin alerta")
    }

    @Test
    func theSubtaskChipShowsOnlyWhenTheyExist() {
        #expect(PriorityDetailLabels.subtasks(SubtaskProgress(done: 1, total: 3)) == "1/3 subtareas")
        #expect(PriorityDetailLabels.subtasks(SubtaskProgress(done: 0, total: 0)) == nil)
    }

    @Test
    func theStateChipFollowsDone() throws {
        let store = try makeStore()
        let open = try store.addPriority(title: "A", list: .today)
        #expect(PriorityDetailLabels.state(of: open) == "Pendiente")
        let done = try store.markDone(open.id)
        #expect(PriorityDetailLabels.state(of: done) == "Hecha")
    }

    @Test
    func theBackLabelIsTheListName() {
        #expect(PriorityList.today.title == "Hoy")
        #expect(PriorityList.week.title == "Semana")
    }
}
