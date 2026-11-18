import Foundation
import Testing
@testable import DailyZGT

@Suite
struct DueFilterTests {
    static let lima = TimeZone(identifier: "America/Lima") ?? .gmt
    static let tokyo = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
    static let newYork = TimeZone(identifier: "America/New_York") ?? .gmt
    static let santiago = TimeZone(identifier: "America/Santiago") ?? .gmt

    static func at(_ text: String, in timeZone: TimeZone = lima) -> Date {
        LocalTime.date(from: text, in: timeZone) ?? .distantPast
    }

    static func days(_ text: String = "2026-11-17T10:24:00", in timeZone: TimeZone = lima) -> DueDays {
        DueDays(now: at(text, in: timeZone), timeZone: timeZone)
    }

    static func item(_ id: String, due: String?, done: String? = nil, in timeZone: TimeZone = lima) -> Priority {
        Priority(
            id: id,
            title: id,
            note: "",
            level: .medium,
            list: .today,
            dueAt: due.map { at($0, in: timeZone) },
            doneAt: done.map { at($0, in: timeZone) },
            position: 0,
            createdAt: .distantPast,
            updatedAt: .distantPast
        )
    }

    static let sample = [
        item("lastWeek", due: "2026-11-10T09:00:00"),
        item("monday", due: "2026-11-16T09:00:00"),
        item("thisMorning", due: "2026-11-17T09:00:00"),
        item("thisAfternoon", due: "2026-11-17T17:00:00"),
        item("tomorrow", due: "2026-11-18T09:00:00"),
        item("thursday", due: "2026-11-19T12:00:00"),
        item("sundayNight", due: "2026-11-22T23:59:00"),
        item("nextMonday", due: "2026-11-23T00:00:00"),
        item("noDate", due: nil),
    ]

    static func ids(_ filter: DueFilter, _ days: DueDays = days()) -> [String] {
        filter.open(sample, days).map(\.id)
    }

    static func groups(_ filter: DueFilter, _ days: DueDays = days()) -> [String] {
        filter.groups(sample, days).map { "\($0.title ?? "-"):\($0.priorities.map(\.id).joined(separator: ","))" }
    }

    @Test
    func todayShowsOverdueFirstThenTodayThenNoDate() {
        #expect(Self.groups(.today) == [
            "Vencidas:lastWeek,monday,thisMorning",
            "Hoy:thisAfternoon",
            "Sin fecha:noDate",
        ])
    }

    @Test
    func todayCountsOverdueAndDueTodayButNotNoDate() {
        #expect(DueFilter.today.counted(Self.sample, Self.days()).map(\.id) == ["lastWeek", "monday", "thisMorning", "thisAfternoon"])
        #expect(DueFilter.all.counted(Self.sample, Self.days()).count == Self.sample.count)
    }

    @Test
    func tomorrowShowsOnlyTheDueOfTomorrowAndCountsTheHiddenOverdue() {
        #expect(Self.groups(.tomorrow) == ["-:tomorrow"])
        #expect(DueFilter.tomorrow.hiddenOverdueCount(Self.sample, Self.days()) == 3)
        #expect(DueFilter.today.hiddenOverdueCount(Self.sample, Self.days()) == 0)
        #expect(DueFilter.overdue.hiddenOverdueCount(Self.sample, Self.days()) == 0)
        #expect(DueFilter.all.hiddenOverdueCount(Self.sample, Self.days()) == 0)
    }

    @Test
    func thisWeekRunsFromMondayToSundayWithOneGroupForEachDay() {
        #expect(Self.groups(.week) == [
            "Lunes 16:monday",
            "Martes 17:thisMorning,thisAfternoon",
            "Miércoles 18:tomorrow",
            "Jueves 19:thursday",
            "Domingo 22:sundayNight",
        ])
        #expect(DueFilter.week.hiddenOverdueCount(Self.sample, Self.days()) == 1)
    }

    @Test
    func overdueShowsEachOpenDueBeforeNowByDay() {
        #expect(Self.groups(.overdue) == [
            "Martes 10:lastWeek",
            "Lunes 16:monday",
            "Martes 17:thisMorning",
        ])
    }

    @Test
    func noDateShowsOnlyPrioritiesWithoutDue() {
        #expect(Self.ids(.noDate) == ["noDate"])
        #expect(DueFilter.noDate.hiddenOverdueCount(Self.sample, Self.days()) == 3)
    }

    @Test
    func allShowsEachOpenPriorityInDateGroups() {
        #expect(Self.groups(.all) == [
            "Vencidas:lastWeek,monday,thisMorning",
            "Hoy:thisAfternoon",
            "Mañana:tomorrow",
            "Jueves 19:thursday",
            "Domingo 22:sundayNight",
            "Lunes 23:nextMonday",
            "Sin fecha:noDate",
        ])
    }

    @Test
    func aPickedDayShowsOnlyThatDay() {
        #expect(Self.groups(.day("2026-11-19")) == ["-:thursday"])
        #expect(Self.groups(.day("2026-11-16")) == ["-:monday"])
        #expect(Self.ids(.day("2026-11-20")).isEmpty)
    }

    @Test
    func aPickedDayKeepsItsDateAndReadsAsTodayOrTomorrow() {
        let days = Self.days()
        #expect(DueFilter.day("2026-11-17").resolved(days) == .today)
        #expect(DueFilter.day("2026-11-18").resolved(days) == .tomorrow)
        #expect(DueFilter.day("2026-11-19").resolved(days) == .day("2026-11-19"))
        #expect(DueFilter.picked(day: Self.at("2026-11-17T00:00:00"), days) == .day("2026-11-17"))
        #expect(DueFilter.picked(day: Self.at("2026-11-18T00:00:00"), days) == .day("2026-11-18"))
        #expect(DueFilter.picked(day: Self.at("2026-11-17T00:00:00"), days).resolved(days) == .today)
    }

    @Test
    func aRangeIncludesBothEdgeDays() {
        let edges = [
            Self.item("before", due: "2026-11-16T23:59:59"),
            Self.item("firstMinute", due: "2026-11-17T00:00:00"),
            Self.item("lastMinute", due: "2026-11-24T23:59:59"),
            Self.item("after", due: "2026-11-25T00:00:00"),
            Self.item("noDate", due: nil),
        ]
        let range = DueFilter.range("2026-11-17", "2026-11-24")
        #expect(range.open(edges, Self.days()).map(\.id) == ["firstMinute", "lastMinute"])
        #expect(range.groups(edges, Self.days()).map(\.title) == ["Martes 17", "Martes 24"])
    }

    @Test
    func aRangeWithTheDaysSwappedIsTheSameRange() {
        let days = Self.days()
        #expect(DueFilter.range("2026-11-24", "2026-11-17").resolved(days) == .range("2026-11-17", "2026-11-24"))
        #expect(DueFilter.picked(from: Self.at("2026-11-24T00:00:00"), to: Self.at("2026-11-17T00:00:00"), days) == .range("2026-11-17", "2026-11-24"))
    }

    @Test
    func theDayStepsGoBackAndForward() {
        let days = Self.days()
        #expect(DueFilter.today.stepped(by: 1, days) == .tomorrow)
        #expect(DueFilter.tomorrow.stepped(by: 1, days) == .day("2026-11-19"))
        #expect(DueFilter.tomorrow.stepped(by: -1, days) == .today)
        #expect(DueFilter.today.stepped(by: -1, days) == .day("2026-11-16"))
        #expect(DueFilter.day("2026-11-19").stepped(by: -1, days) == .tomorrow)
        #expect(DueFilter.week.stepped(by: 1, days) == nil)
        #expect(DueFilter.all.stepped(by: 1, days) == nil)
        #expect(DueFilter.range("2026-11-17", "2026-11-24").stepped(by: 1, days) == nil)
    }

    @Test
    func theDayStepsCrossTheMonthAndTheYear() {
        let days = Self.days()
        #expect(DueFilter.day("2026-11-30").stepped(by: 1, days) == .day("2026-12-01"))
        #expect(DueFilter.day("2026-12-01").stepped(by: -1, days) == .day("2026-11-30"))
        #expect(DueFilter.day("2026-12-31").stepped(by: 1, days) == .day("2027-01-01"))
        #expect(DueFilter.day("2027-01-01").stepped(by: -1, days) == .day("2026-12-31"))
        #expect(DueFilter.day("2028-02-28").stepped(by: 1, days) == .day("2028-02-29"))
    }

    @Test
    func theDayStepsCrossAClockChange() {
        let newYork = Self.days("2026-03-01T10:00:00", in: Self.newYork)
        #expect(DueFilter.day("2026-03-07").stepped(by: 1, newYork) == .day("2026-03-08"))
        #expect(DueFilter.day("2026-03-08").stepped(by: 1, newYork) == .day("2026-03-09"))
        let santiago = Self.days("2026-08-20T10:00:00", in: Self.santiago)
        #expect(DueFilter.day("2026-09-05").stepped(by: 1, santiago) == .day("2026-09-06"))
        #expect(DueFilter.day("2026-09-06").stepped(by: 1, santiago) == .day("2026-09-07"))
        let lateNight = Self.item("late", due: "2026-09-06T23:30:00", in: Self.santiago)
        #expect(DueFilter.day("2026-09-06").includes(lateNight, santiago))
        #expect(!DueFilter.day("2026-09-07").includes(lateNight, santiago))
    }

    @Test
    func theDaysFollowTheTimeZone() {
        let instant = Self.at("2026-11-17T10:24:00")
        let lima = DueDays(now: instant, timeZone: Self.lima)
        let tokyo = DueDays(now: instant, timeZone: Self.tokyo)
        let due = Self.item("due", due: "2026-11-18T09:00:00")
        #expect(DueFilter.tomorrow.includes(due, lima))
        #expect(!DueFilter.today.includes(due, lima))
        #expect(DueFilter.today.includes(due, tokyo))
        #expect(!DueFilter.tomorrow.includes(due, tokyo))
        #expect(DueFilter.day("2026-11-18").resolved(lima) == .tomorrow)
        #expect(DueFilter.day("2026-11-18").resolved(tokyo) == .today)
    }

    @Test
    func theDoneListFollowsTheDateWindowOfTheFilter() {
        let days = Self.days()
        let doneToday = Self.item("doneToday", due: nil, done: "2026-11-17T08:00:00")
        let doneLastNight = Self.item("doneLastNight", due: nil, done: "2026-11-16T23:00:00")
        let doneMonday = Self.item("doneMonday", due: nil, done: "2026-11-16T10:00:00")
        #expect(DueFilter.today.showsDone(doneToday, days))
        #expect(!DueFilter.today.showsDone(doneLastNight, days))
        #expect(!DueFilter.tomorrow.showsDone(doneToday, days))
        #expect(DueFilter.week.showsDone(doneMonday, days))
        #expect(DueFilter.day("2026-11-16").showsDone(doneMonday, days))
        #expect(DueFilter.all.showsDone(doneLastNight, days))
        #expect(!DueFilter.all.showsDone(doneMonday, days))
        #expect(DueFilter.overdue.showsDone(doneToday, days))
        #expect(DueFilter.noDate.showsDone(doneToday, days))
        #expect(!DueFilter.today.showsDone(Self.item("open", due: nil), days))
    }

    @Test
    func aNewPriorityGetsTheDayOfTheFilterWithTheDefaultTime() {
        let days = Self.days()
        #expect(DueFilter.today.newDue(days) == nil)
        #expect(DueFilter.all.newDue(days) == nil)
        #expect(DueFilter.overdue.newDue(days) == nil)
        #expect(DueFilter.noDate.newDue(days) == nil)
        #expect(DueFilter.tomorrow.newDue(days) == Self.at("2026-11-18T11:00:00"))
        #expect(DueFilter.day("2026-11-19").newDue(days) == Self.at("2026-11-19T11:00:00"))
        #expect(DueFilter.week.newDue(days) == Self.at("2026-11-17T11:00:00"))
        #expect(DueFilter.range("2026-11-20", "2026-11-22").newDue(days) == Self.at("2026-11-20T11:00:00"))
        #expect(DueFilter.range("2026-11-10", "2026-11-20").newDue(days) == Self.at("2026-11-17T11:00:00"))
        #expect(DueFilter.range("2026-11-01", "2026-11-03").newDue(days) == Self.at("2026-11-01T11:00:00"))
    }

    @Test
    func thePriorityHomeIsHoyOrTheDayOfItsDue() {
        let days = Self.days()
        #expect(DueFilter.home(for: Self.item("a", due: nil), days) == .today)
        #expect(DueFilter.home(for: Self.item("b", due: "2026-11-10T09:00:00"), days) == .today)
        #expect(DueFilter.home(for: Self.item("c", due: "2026-11-18T09:00:00"), days) == .tomorrow)
        #expect(DueFilter.home(for: Self.item("d", due: "2026-11-25T09:00:00"), days) == .day("2026-11-25"))
    }

    @Test
    func aRangePickTakesTwoDaysInAnyOrder() {
        var pick = RangePick()
        let first = Self.at("2026-11-24T00:00:00")
        let last = Self.at("2026-11-17T00:00:00")
        #expect(pick.pick(first) == nil)
        #expect(pick.first == first)
        let range = pick.pick(last)
        #expect(range?.0 == last)
        #expect(range?.1 == first)
        #expect(pick.first == nil)
    }

    @Test
    func theFilterIsSavedAsJSONAndReadBack() throws {
        for filter in DueFilter.quickOptions + [.day("2026-11-19"), .range("2026-11-17", "2026-11-24")] {
            let data = try JSONEncoder().encode(filter)
            #expect(try JSONDecoder().decode(DueFilter.self, from: data) == filter)
        }
    }

    @Test
    func theHeaderNamesTheFilterAndItsDays() {
        let days = Self.days()
        let cases: [(DueFilter, String, String?)] = [
            (.today, "Hoy", "martes 17 nov"),
            (.tomorrow, "Mañana", "miércoles 18 nov"),
            (.week, "Esta semana", "16–22 nov"),
            (.overdue, "Vencidas", "antes de hoy"),
            (.noDate, "Sin fecha", nil),
            (.all, "Todas", "9 abiertas"),
            (.day("2026-11-19"), "jueves 19 nov", "en 2 días"),
            (.day("2026-11-16"), "lunes 16 nov", "ayer"),
            (.day("2026-11-14"), "sábado 14 nov", "hace 3 días"),
            (.range("2026-11-17", "2026-11-24"), "17 – 24 nov", "8 días"),
            (.range("2026-11-28", "2026-12-03"), "28 nov – 3 dic", "6 días"),
            (.range("2026-12-30", "2027-01-02"), "30 dic 2026 – 2 ene 2027", "4 días"),
            (.range("2026-11-20", "2026-11-20"), "20 – 20 nov", "1 día"),
        ]
        for (filter, title, subtitle) in cases {
            #expect(DueFilterLabels.title(filter, days) == title)
            #expect(DueFilterLabels.subtitle(filter, days, openCount: 9) == subtitle)
        }
        #expect(DueFilterLabels.subtitle(.all, days, openCount: 1) == "1 abierta")
        #expect(DueFilterLabels.subtitle(.week, Self.days("2026-09-30T10:00:00"), openCount: 0) == "28 sep–4 oct")
    }

    @Test
    func eachFilterHasItsEmptyState() {
        let days = Self.days()
        #expect(DueFilterLabels.empty(.today, days) == "Nada vence hoy.")
        #expect(DueFilterLabels.empty(.tomorrow, days) == "Nada vence mañana.")
        #expect(DueFilterLabels.empty(.day("2026-11-19"), days) == "Nada vence el jueves 19 nov.")
        #expect(DueFilterLabels.empty(.week, days) == "Nada vence esta semana.")
        #expect(DueFilterLabels.empty(.range("2026-11-17", "2026-11-24"), days) == "Nada vence entre el 17 y el 24 nov.")
        #expect(DueFilterLabels.empty(.range("2026-11-28", "2026-12-03"), days) == "Nada vence entre el 28 nov y el 3 dic.")
        #expect(DueFilterLabels.empty(.overdue, days) == "Nada vencido.")
        #expect(DueFilterLabels.empty(.noDate, days) == "Cada prioridad tiene fecha.")
        #expect(DueFilterLabels.empty(.all, days) == "Nada pendiente.")
    }

    @Test
    func theSummaryNamesTheWindowOfTheFilter() {
        let days = Self.days()
        #expect(DueFilterLabels.summary(.today, days, done: 1, total: 4) == "1 de 4 hechas hoy")
        #expect(DueFilterLabels.summary(.tomorrow, days, done: 0, total: 1) == "0 de 1 hechas mañana")
        #expect(DueFilterLabels.summary(.day("2026-11-19"), days, done: 0, total: 2) == "0 de 2 hechas el jueves 19")
        #expect(DueFilterLabels.summary(.week, days, done: 3, total: 9) == "3 de 9 hechas esta semana")
        #expect(DueFilterLabels.summary(.range("2026-11-17", "2026-11-24"), days, done: 2, total: 5) == "2 de 5 hechas en el rango")
        #expect(DueFilterLabels.summary(.all, days, done: 2, total: 5) == "2 de 5 hechas en 24 h")
        #expect(DueFilterLabels.overdueLink(1) == "1 vencida")
        #expect(DueFilterLabels.overdueLink(3) == "3 vencidas")
    }

    @Test
    func aDayGroupNamesTheMonthOnlyWhenItIsNotTheMonthOfToday() {
        let days = Self.days()
        #expect(DueFilterLabels.dayGroup("2026-11-16", days) == "Lunes 16")
        #expect(DueFilterLabels.dayGroup("2026-10-28", days) == "Miércoles 28 oct")
        #expect(DueFilterLabels.dayGroup("2027-11-16", days) == "Martes 16 nov")
    }
}

@Suite
struct LocalTimeDayTests {
    @Test
    func readsTheDayKeyBackToTheStartOfTheDay() {
        let lima = DueFilterTests.lima
        #expect(LocalTime.day(from: "2026-11-17", in: lima) == DueFilterTests.at("2026-11-17T00:00:00"))
        #expect(LocalTime.day(from: "not a day", in: lima) == nil)
        let date = DueFilterTests.at("2026-11-17T23:30:00")
        #expect(LocalTime.day(from: LocalTime.dayKey(for: date, in: lima), in: lima) == DueFilterTests.at("2026-11-17T00:00:00"))
    }
}
