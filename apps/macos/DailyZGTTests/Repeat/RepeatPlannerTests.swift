import Foundation
import Testing
@testable import DailyZGT

func repeatPriority(
    _ id: String,
    series: String? = nil,
    rule: RepeatRule = .daily,
    done: String? = nil,
    due: String? = nil,
    created: String = "2026-10-10T09:00:00",
    position: Int = 1,
    level: PriorityLevel = .medium,
    list: PriorityList = .today,
    title: String = "Meditar",
    note: String = ""
) -> Priority {
    Priority(
        id: id,
        title: title,
        note: note,
        level: level,
        list: list,
        dueAt: due.map(localDate),
        doneAt: done.map(localDate),
        position: position,
        createdAt: localDate(created),
        updatedAt: localDate(done ?? created),
        repeatRule: rule,
        repeatSeriesID: series
    )
}

func repeatSubtask(_ id: String, of priorityID: String, _ title: String, position: Int, done: Bool = false) -> Subtask {
    let at = localDate("2026-10-10T09:00:00")
    return Subtask(id: id, priorityID: priorityID, title: title, doneAt: done ? at : nil, position: position, createdAt: at)
}

@Suite
struct RepeatPlannerTests {
    let now = localDate("2026-10-13T09:00:00")

    private func copies(_ priorities: Priority..., subtasks: [Subtask] = []) -> [RepeatCopy] {
        RepeatPlanner.copies(
            of: priorities,
            subtasks: Dictionary(grouping: subtasks, by: \.priorityID),
            now: now
        )
    }

    @Test
    func aDailyPriorityDoneYesterdayGetsOneCopyWithTheSameContent() {
        let source = repeatPriority(
            "p1",
            done: "2026-10-12T21:00:00",
            due: "2026-10-12T18:30:00",
            level: .high,
            title: "Meditar",
            note: "Diez minutos."
        )
        let result = copies(source, subtasks: [
            repeatSubtask("s2", of: "p1", "Estirar", position: 2),
            repeatSubtask("s1", of: "p1", "Respirar", position: 1, done: true),
            repeatSubtask("s9", of: "other", "De otra", position: 1),
        ])

        #expect(result == [
            RepeatCopy(
                sourceID: "p1",
                seriesID: "p1",
                title: "Meditar",
                note: "Diez minutos.",
                level: .high,
                dueAt: localDate("2026-10-13T18:30:00"),
                subtaskTitles: ["Respirar", "Estirar"]
            ),
        ])
    }

    @Test
    func aPriorityDoneTodayGetsNoCopyToday() {
        #expect(copies(repeatPriority("p1", done: "2026-10-13T00:00:00")).isEmpty)
        #expect(copies(repeatPriority("p1", done: "2026-10-13T08:59:59")).isEmpty)
    }

    @Test
    func theLastSecondOfYesterdayIsYesterday() {
        #expect(copies(repeatPriority("p1", done: "2026-10-12T23:59:59")).map(\.sourceID) == ["p1"])
    }

    @Test
    func severalMissedDaysGiveOneCopyForToday() {
        let result = copies(repeatPriority("p1", done: "2026-10-05T07:00:00", due: "2026-10-05T08:15:00"))
        #expect(result.count == 1)
        #expect(result.first?.dueAt == localDate("2026-10-13T08:15:00"))
    }

    @Test
    func aDueTimeBeforeNowStaysOnToday() {
        let late = localDate("2026-10-13T20:00:00")
        let result = RepeatPlanner.copies(
            of: [repeatPriority("p1", done: "2026-10-12T07:00:00", due: "2026-10-11T08:15:30")],
            subtasks: [:],
            now: late
        )
        #expect(result.first?.dueAt == localDate("2026-10-13T08:15:30"))
    }

    @Test
    func noDueStaysNoDue() {
        let result = copies(repeatPriority("p1", done: "2026-10-12T07:00:00"))
        #expect(result.count == 1)
        #expect(result.first?.dueAt == nil)
        #expect(result.first?.subtaskTitles == [])
    }

    @Test
    func anOpenDailyPriorityGetsNoCopy() {
        #expect(copies(repeatPriority("p1", created: "2026-10-01T09:00:00")).isEmpty)
    }

    @Test
    func aSeriesWithAnOpenCopyGetsNoCopy() {
        #expect(copies(
            repeatPriority("p1", done: "2026-10-11T21:00:00"),
            repeatPriority("p2", series: "p1", created: "2026-10-12T00:00:05", position: 2)
        ).isEmpty)
    }

    @Test
    func anOpenCopyWithTheRuleOffStillBlocksANewCopy() {
        #expect(copies(
            repeatPriority("p1", done: "2026-10-11T21:00:00"),
            repeatPriority("p2", series: "p1", rule: .none, created: "2026-10-12T00:00:05", position: 2)
        ).isEmpty)
    }

    @Test
    func theRuleNoneGivesNoCopy() {
        #expect(copies(repeatPriority("p1", rule: .none, done: "2026-10-12T21:00:00")).isEmpty)
    }

    @Test
    func theCopyThatWasDoneLastDecidesTheRuleAndTheContent() {
        let first = repeatPriority("p1", done: "2026-10-11T21:00:00", title: "Old")
        let offLast = repeatPriority(
            "p2", series: "p1", rule: .none, done: "2026-10-12T21:00:00", created: "2026-10-12T00:00:05", position: 2
        )
        #expect(copies(first, offLast).isEmpty)

        let onLast = repeatPriority(
            "p2", series: "p1", done: "2026-10-12T21:00:00", created: "2026-10-12T00:00:05", position: 2, title: "New"
        )
        let offFirst = repeatPriority("p1", rule: .none, done: "2026-10-11T21:00:00", title: "Old")
        let result = copies(offFirst, onLast)
        #expect(result.map(\.sourceID) == ["p2"])
        #expect(result.map(\.title) == ["New"])
        #expect(result.map(\.seriesID) == ["p1"])
    }

    @Test
    func anOlderCopyThatWasDoneLaterIsTheSource() {
        let restoredAndDoneToday = repeatPriority("p1", done: "2026-10-13T08:00:00", created: "2026-10-01T09:00:00")
        let doneYesterday = repeatPriority(
            "p2", series: "p1", done: "2026-10-12T21:00:00", created: "2026-10-12T00:00:05", position: 2
        )
        #expect(copies(restoredAndDoneToday, doneYesterday).isEmpty)

        let tomorrow = RepeatPlanner.copies(
            of: [restoredAndDoneToday, doneYesterday],
            subtasks: [:],
            now: localDate("2026-10-14T00:00:00")
        )
        #expect(tomorrow.map(\.sourceID) == ["p1"])
    }

    @Test
    func aSeriesGoesOnWhenItsFirstPriorityIsGone() {
        let result = copies(
            repeatPriority("p2", series: "p1", done: "2026-10-11T21:00:00", position: 2),
            repeatPriority("p3", series: "p1", done: "2026-10-12T21:00:00", position: 3, title: "Third")
        )
        #expect(result.map(\.sourceID) == ["p3"])
        #expect(result.map(\.seriesID) == ["p1"])
    }

    @Test
    func eachSeriesGetsItsOwnCopyInTheOrderOfThePositions() {
        let result = copies(
            repeatPriority("b", done: "2026-10-12T21:00:00", position: 7, title: "Leer"),
            repeatPriority("a", done: "2026-10-12T20:00:00", position: 9, title: "Correr"),
            repeatPriority("c", done: "2026-10-12T20:00:00", position: 3, list: .week, title: "Meditar"),
            repeatPriority("d", rule: .none, done: "2026-10-12T20:00:00", position: 1, title: "Una vez"),
            repeatPriority("e", position: 2, title: "Abierta")
        )
        #expect(result.map(\.title) == ["Meditar", "Leer", "Correr"])
        #expect(result.map(\.seriesID) == ["c", "b", "a"])
    }

    @Test
    func theCopyMakesTheSeriesNotReady() {
        let source = repeatPriority("p1", done: "2026-10-12T21:00:00")
        let copy = copies(source)[0]
        let open = repeatPriority("p2", series: copy.seriesID, created: "2026-10-13T09:00:00", position: 2)
        #expect(copies(source, open).isEmpty)
    }

    @Test
    func theDayComesFromTheCalendarOfTheClock() throws {
        var lima = Calendar(identifier: .gregorian)
        lima.timeZone = try #require(TimeZone(identifier: "America/Lima"))
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(identifier: "UTC"))

        let doneAt = try #require(lima.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 23, minute: 30)))
        let dueAt = try #require(lima.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 22)))
        let clock = try #require(lima.date(from: DateComponents(year: 2026, month: 10, day: 13, hour: 5)))
        var source = repeatPriority("p1")
        source.doneAt = doneAt
        source.dueAt = dueAt

        let inLima = RepeatPlanner.copies(of: [source], subtasks: [:], now: clock, calendar: lima)
        #expect(inLima.count == 1)
        #expect(inLima.first?.dueAt == lima.date(from: DateComponents(year: 2026, month: 10, day: 13, hour: 22)))

        let inUTC = RepeatPlanner.copies(of: [source], subtasks: [:], now: clock, calendar: utc)
        #expect(inUTC.isEmpty)
    }

    @Test
    func aClockThatGoesBackGivesNoCopy() {
        let result = RepeatPlanner.copies(
            of: [repeatPriority("p1", done: "2026-10-12T21:00:00")],
            subtasks: [:],
            now: localDate("2026-10-11T09:00:00")
        )
        #expect(result.isEmpty)
    }

    @Test
    func aDueTimeThatDoesNotExistTodayMovesToTheNextTimeOfToday() throws {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let due = try #require(newYork.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 2, minute: 30)))
        let clock = try #require(newYork.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 9)))

        let moved = try #require(RepeatPlanner.sameTime(as: due, onTheDayOf: clock, calendar: newYork))
        #expect(newYork.isDate(moved, inSameDayAs: clock))
        #expect(newYork.component(.hour, from: moved) == 3)
    }
}
