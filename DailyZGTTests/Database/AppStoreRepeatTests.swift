import Foundation
import GRDB
import Testing
@testable import DailyZGT

@MainActor
@discardableResult
func addDaily(
    _ store: AppStore,
    title: String = "Meditar",
    level: PriorityLevel = .medium,
    list: PriorityList = .today,
    due: String? = nil,
    note: String = ""
) throws -> Priority {
    let added = try store.addPriority(title: title, level: level, list: list, dueAt: due.map(localDate), note: note)
    return try store.editPriority(added.id, { $0.repeatRule = .daily })
}

@MainActor
func openCopiesBySeries(_ store: AppStore) throws -> [Int] {
    try values(
        "SELECT COUNT(*) FROM priority WHERE done_at IS NULL GROUP BY COALESCE(repeat_series_id, id) ORDER BY 1 DESC",
        in: store.database
    )
}

@Suite
@MainActor
struct AppStoreRepeatTests {
    let clock = TestClock("2026-10-12T09:00:00")

    private func types(_ store: AppStore, _ id: Priority.ID) throws -> [PriorityEventType] {
        try store.events(of: id).map(\.type)
    }

    @discardableResult
    private func doneDaily(_ store: AppStore, title: String = "Meditar", list: PriorityList = .today) throws -> Priority {
        let added = try addDaily(store, title: title, list: list)
        return try store.markDone(added.id)
    }

    private func nextDay(_ text: String = "2026-10-13T07:00:00") {
        clock.date = localDate(text)
    }

    @Test
    func theNextDayAddsOneOpenCopyToHoy() throws {
        let store = try makeStore(clock)
        try store.addPriority(title: "Otra", list: .week)
        let source = try addDaily(
            store,
            title: "Meditar",
            level: .high,
            due: "2026-10-12T18:30:00",
            note: "Diez minutos."
        )
        let first = try store.addSubtask(to: source.id, title: "Respirar")
        try store.addSubtask(to: source.id, title: "Estirar")
        try store.toggleSubtask(first.id)
        clock.date = localDate("2026-10-12T21:00:00")
        try store.markDone(source.id)
        let sourceEvents = try types(store, source.id)

        nextDay()
        let added = try store.addRepeatCopies()

        let copy = try #require(added.first)
        #expect(added.count == 1)
        #expect(copy.id != source.id)
        #expect(copy.title == "Meditar")
        #expect(copy.level == .high)
        #expect(copy.note == "Diez minutos.")
        #expect(copy.list == .today)
        #expect(copy.repeatRule == .daily)
        #expect(copy.repeatSeriesID == source.id)
        #expect(copy.seriesID == source.id)
        #expect(copy.dueAt == localDate("2026-10-13T18:30:00"))
        #expect(copy.doneAt == nil)
        #expect(copy.createdAt == localDate("2026-10-13T07:00:00"))
        #expect(copy.position == 3)
        #expect(store.priority(id: copy.id) == copy)

        #expect(store.openPriorities(in: .today).map(\.id) == [copy.id])
        #expect(store.donePriorities(in: .today).map(\.id) == [source.id])
        #expect(store.openCount(in: .today) == 1)
        #expect(store.openCount(in: .week) == 1)

        let copied = store.subtasks(of: copy.id)
        #expect(copied.map(\.title) == ["Respirar", "Estirar"])
        #expect(copied.map(\.isDone) == [false, false])
        #expect(copied.map(\.position) == [1, 2])
        #expect(Set(copied.map(\.id)).isDisjoint(with: store.subtasks(of: source.id).map(\.id)))
        #expect(store.subtasks(of: source.id).map(\.isDone) == [true, false])

        #expect(try types(store, copy.id) == [.created])
        #expect(try store.events(of: copy.id).map(\.at) == [localDate("2026-10-13T07:00:00")])
        #expect(try types(store, source.id) == sourceEvents)
        #expect(store.priority(id: source.id)?.doneAt == localDate("2026-10-12T21:00:00"))
        #expect(try values(
            "SELECT due_at || ' ' || created_at || ' ' || repeat_rule || ' ' || repeat_series_id FROM priority WHERE id = '\(copy.id)'",
            in: store.database
        ) == ["2026-10-13T18:30:00 2026-10-13T07:00:00 daily \(source.id)"])
    }

    @Test
    func twoRunsInARowAddNothingTheSecondTime() throws {
        let store = try makeStore(clock)
        try doneDaily(store)
        try doneDaily(store, title: "Leer")
        nextDay()

        #expect(try store.addRepeatCopies().map(\.title) == ["Meditar", "Leer"])
        #expect(try store.addRepeatCopies().isEmpty)
        clock.advance(minutes: 600)
        #expect(try store.addRepeatCopies().isEmpty)

        #expect(store.openPriorities(in: .today).count == 2)
        #expect(try values("SELECT COUNT(*) FROM priority", in: store.database) == [4])
        #expect(try values("SELECT COUNT(*) FROM priority_event WHERE type = 'created'", in: store.database) == [4])
        #expect(try openCopiesBySeries(store) == [1, 1])
    }

    @Test
    func aPriorityDoneTodayGetsItsCopyOnTheNextDayOnly() throws {
        let store = try makeStore(clock)
        try doneDaily(store)

        #expect(try store.addRepeatCopies().isEmpty)
        clock.date = localDate("2026-10-12T23:59:59")
        #expect(try store.addRepeatCopies().isEmpty)
        clock.date = localDate("2026-10-13T00:00:00")
        #expect(try store.addRepeatCopies().count == 1)
    }

    @Test
    func severalMissedDaysAddOneCopyForToday() throws {
        let store = try makeStore(clock)
        let source = try addDaily(store, due: "2026-10-12T08:15:00")
        try store.markDone(source.id)

        nextDay("2026-10-19T10:00:00")
        let added = try store.addRepeatCopies()

        #expect(added.count == 1)
        #expect(added.first?.dueAt == localDate("2026-10-19T08:15:00"))
        #expect(try values("SELECT COUNT(*) FROM priority", in: store.database) == [2])
    }

    @Test
    func aCopyThatIsStillOpenOnTheNextDayStaysAlone() throws {
        let store = try makeStore(clock)
        try doneDaily(store)
        nextDay()
        let copy = try #require(try store.addRepeatCopies().first)

        nextDay("2026-10-14T07:00:00")
        #expect(try store.addRepeatCopies().isEmpty)
        nextDay("2026-10-20T07:00:00")
        #expect(try store.addRepeatCopies().isEmpty)
        #expect(store.openPriorities(in: .today).map(\.id) == [copy.id])
    }

    @Test
    func theRuleOffOnTheOpenCopyEndsTheSeriesWhenTheCopyIsDone() throws {
        let store = try makeStore(clock)
        try doneDaily(store)
        nextDay()
        let copy = try #require(try store.addRepeatCopies().first)

        try store.editPriority(copy.id, { $0.repeatRule = .none })
        try store.markDone(copy.id)
        nextDay("2026-10-14T07:00:00")

        #expect(try store.addRepeatCopies().isEmpty)
        #expect(store.openPriorities(in: .today).isEmpty)
    }

    @Test
    func theRuleOffOnTheCopyThatWasDoneLastEndsTheSeries() throws {
        let store = try makeStore(clock)
        let source = try doneDaily(store)
        try store.editPriority(source.id, { $0.repeatRule = .none })
        nextDay()

        #expect(try store.addRepeatCopies().isEmpty)

        try store.editPriority(source.id, { $0.repeatRule = .daily })
        #expect(try store.addRepeatCopies().count == 1)
    }

    @Test
    func aDailyPriorityOfSemanaGetsItsCopyInHoy() throws {
        let store = try makeStore(clock)
        let source = try doneDaily(store, list: .week)
        nextDay()
        let copy = try #require(try store.addRepeatCopies().first)

        #expect(copy.list == .today)
        #expect(store.donePriorities(in: .week).map(\.id) == [source.id])
        #expect(store.openPriorities(in: .week).isEmpty)

        try store.movePriority(copy.id, to: .week)
        try store.markDone(copy.id)
        nextDay("2026-10-14T07:00:00")
        let third = try #require(try store.addRepeatCopies().first)
        #expect(third.list == .today)
        #expect(third.seriesID == source.id)
    }

    @Test
    func eachCopyOfASeriesHasTheSameSeriesAndTheLastContent() throws {
        let store = try makeStore(clock)
        let source = try doneDaily(store)
        var last = source
        for day in 13...16 {
            nextDay("2026-10-\(day)T07:00:00")
            let copy = try #require(try store.addRepeatCopies().first)
            #expect(try store.addRepeatCopies().isEmpty)
            #expect(try openCopiesBySeries(store) == [1])
            #expect(copy.seriesID == source.id)
            try store.editPriority(copy.id, { $0.title = "Meditar \(day)" })
            last = try store.markDone(copy.id)
        }
        #expect(last.title == "Meditar 16")
        nextDay("2026-10-17T07:00:00")
        #expect(try store.addRepeatCopies().map(\.title) == ["Meditar 16"])
        #expect(try values("SELECT COUNT(DISTINCT COALESCE(repeat_series_id, id)) FROM priority", in: store.database) == [1])
        #expect(try values("SELECT COUNT(*) FROM priority", in: store.database) == [6])
    }

    @Test
    func aPriorityWrittenBySqlite3WithNoSeriesStartsItsSeries() throws {
        let store = try makeStore(clock)
        try execute(
            """
            INSERT INTO priority (id, title, level, list, done_at, position, created_at, updated_at, repeat_rule)
            VALUES ('p1', 'From sqlite3', 'low', 'week', '2026-10-11T22:00:00', 1,
                    '2026-10-11T09:00:00', '2026-10-11T22:00:00', 'daily')
            """,
            in: store.database
        )

        let added = try store.addRepeatCopies()
        #expect(added.map(\.title) == ["From sqlite3"])
        #expect(added.map(\.repeatSeriesID) == ["p1"])
        #expect(added.map(\.dueAt) == [nil])
        #expect(store.openPriorities(in: .today).map(\.title) == ["From sqlite3"])
        #expect(try store.addRepeatCopies().isEmpty)
    }

    @Test
    func aRestoreReplacesTheNewerCopyThatThePersonDidNotChange() throws {
        let store = try makeStore(clock)
        let source = try addDaily(store, due: "2026-10-12T23:00:00")
        try store.addSubtask(to: source.id, title: "Respirar")
        try store.markDone(source.id)
        nextDay()
        let copy = try #require(try store.addRepeatCopies().first)
        try store.saveAlerts([
            PriorityAlert(id: "a1", priorityID: copy.id, kind: .atDue, fireAt: localDate("2026-10-13T23:00:00"), status: .scheduled),
        ])

        let restored = try store.restorePriority(source.id)

        #expect(restored.doneAt == nil)
        #expect(restored.repeatRule == .daily)
        #expect(restored.seriesID == source.id)
        #expect(store.priority(id: copy.id) == nil)
        #expect(store.openPriorities(in: .today).map(\.id) == [source.id])
        #expect(store.subtasks(of: copy.id).isEmpty)
        #expect(try values("SELECT COUNT(*) FROM subtask", in: store.database) == [1])
        #expect(try store.alerts().isEmpty)
        #expect(try openCopiesBySeries(store) == [1])
        #expect(try types(store, source.id).last == .restored)
        #expect(try store.addRepeatCopies().isEmpty)
    }

    @Test
    func aRestoreKeepsTheNewerCopyThatThePersonChanged() throws {
        let store = try makeStore(clock)
        let source = try doneDaily(store)
        nextDay()
        let copy = try #require(try store.addRepeatCopies().first)
        try store.addSubtask(to: copy.id, title: "Trabajo de hoy")

        let restored = try store.restorePriority(source.id)

        #expect(restored.doneAt == nil)
        #expect(restored.repeatRule == .none)
        #expect(restored.seriesID != copy.seriesID)
        #expect(store.priority(id: copy.id)?.repeatRule == .daily)
        #expect(store.subtasks(of: copy.id).map(\.title) == ["Trabajo de hoy"])
        #expect(Set(store.openPriorities(in: .today).map(\.id)) == [source.id, copy.id])
        #expect(try openCopiesBySeries(store) == [1, 1])

        try store.markDone(restored.id)
        try store.markDone(copy.id)
        nextDay("2026-10-14T07:00:00")
        let next = try store.addRepeatCopies()
        #expect(next.map(\.seriesID) == [copy.seriesID])
        #expect(try openCopiesBySeries(store) == [1])
    }

    @Test(arguments: [PriorityEventType.edited, .moved, .subtaskDone])
    func eachChangeOfThePersonKeepsTheNewerCopy(change: PriorityEventType) throws {
        let store = try makeStore(clock)
        let source = try addDaily(store)
        try store.addSubtask(to: source.id, title: "Respirar")
        try store.markDone(source.id)
        nextDay()
        let copy = try #require(try store.addRepeatCopies().first)
        switch change {
        case .moved: try store.movePriority(copy.id, to: .week)
        case .subtaskDone: try store.toggleSubtask(try #require(store.subtasks(of: copy.id).first).id)
        default: try store.editPriority(copy.id, { $0.note = "Nota de hoy" })
        }
        #expect(try types(store, copy.id) == [.created, change])

        try store.restorePriority(source.id)

        #expect(store.priority(id: copy.id) != nil)
        #expect(try openCopiesBySeries(store) == [1, 1])
    }

    @Test
    func aRestoreWithNoOpenCopyChangesNoRuleAndNoSeries() throws {
        let store = try makeStore(clock)
        let source = try doneDaily(store)
        let plain = try store.addPriority(title: "Una vez", list: .today)
        try store.markDone(plain.id)

        let restored = try store.restorePriority(source.id)
        let restoredPlain = try store.restorePriority(plain.id)

        #expect(restored.repeatRule == .daily)
        #expect(restored.repeatSeriesID == nil)
        #expect(restoredPlain.repeatRule == .none)
        #expect(restoredPlain.repeatSeriesID == nil)
        #expect(try values("SELECT COUNT(*) FROM priority", in: store.database) == [2])
        nextDay()
        #expect(try store.addRepeatCopies().isEmpty)
    }

    @Test
    func aRestoredCopyThatIsDoneAgainTodayGetsItsCopyOnTheNextDay() throws {
        let store = try makeStore(clock)
        let source = try doneDaily(store)
        nextDay()
        try store.addRepeatCopies()
        try store.restorePriority(source.id)
        try store.editPriority(source.id, { $0.title = "Meditar mejor" })
        try store.markDone(source.id)

        #expect(try store.addRepeatCopies().isEmpty)
        nextDay("2026-10-14T07:00:00")
        #expect(try store.addRepeatCopies().map(\.title) == ["Meditar mejor"])
    }

    @Test
    func theDeleteOfTheOpenCopyEndsTheSeries() throws {
        let store = try makeStore(clock)
        let source = try doneDaily(store)
        nextDay()
        let second = try #require(try store.addRepeatCopies().first)
        try store.markDone(second.id)
        nextDay("2026-10-14T07:00:00")
        let third = try #require(try store.addRepeatCopies().first)
        let eventsBefore = try types(store, source.id)

        clock.advance(minutes: 30)
        try store.deletePriority(third.id)

        #expect(try store.addRepeatCopies().isEmpty)
        #expect(store.priority(id: source.id)?.repeatRule == RepeatRule.none)
        #expect(store.priority(id: second.id)?.repeatRule == RepeatRule.none)
        #expect(try types(store, source.id) == eventsBefore + [.edited])
        #expect(try types(store, second.id).last == .edited)
        #expect(try store.events(of: second.id).last?.at == localDate("2026-10-14T07:30:00"))
        nextDay("2026-10-15T07:00:00")
        #expect(try store.addRepeatCopies().isEmpty)
        #expect(store.openPriorities(in: .today).isEmpty)
    }

    @Test
    func theDeleteOfAnOpenPriorityWithNoSeriesChangesNoOtherRow() throws {
        let store = try makeStore(clock)
        let daily = try doneDaily(store)
        let plain = try store.addPriority(title: "Una vez", list: .today)

        try store.deletePriority(plain.id)

        #expect(store.priority(id: daily.id)?.repeatRule == .daily)
        #expect(try types(store, daily.id) == [.created, .edited, .done])
    }

    @Test
    func theDeleteOfADoneCopyLetsTheSeriesGoOnFromTheLastCopyThatIsLeft() throws {
        let store = try makeStore(clock)
        let source = try doneDaily(store)
        nextDay()
        let second = try #require(try store.addRepeatCopies().first)
        try store.editPriority(second.id, { $0.title = "Meditar dos" })
        try store.markDone(second.id)

        nextDay("2026-10-14T07:00:00")
        try store.deletePriority(second.id)
        let third = try store.addRepeatCopies()

        #expect(third.map(\.title) == ["Meditar"])
        #expect(third.map(\.seriesID) == [source.id])
        #expect(store.priority(id: source.id)?.repeatRule == .daily)
    }

    @Test
    func theDeleteOfTheFirstPriorityKeepsTheSeriesOfItsCopies() throws {
        let store = try makeStore(clock)
        let source = try doneDaily(store)
        nextDay()
        let second = try #require(try store.addRepeatCopies().first)
        try store.markDone(second.id)
        try store.deletePriority(source.id)

        nextDay("2026-10-14T07:00:00")
        let third = try store.addRepeatCopies()
        #expect(third.map(\.seriesID) == [source.id])
        #expect(try openCopiesBySeries(store) == [1])
    }

    @Test
    func theDeleteOfTheOnlyCopyLeavesNoSeries() throws {
        let store = try makeStore(clock)
        let source = try doneDaily(store)
        try store.deletePriority(source.id)
        nextDay()

        #expect(try store.addRepeatCopies().isEmpty)
        #expect(try values("SELECT COUNT(*) FROM priority", in: store.database) == [0])
    }

    @Test
    func editPrioritySetsTheRuleAndCannotChangeTheSeries() throws {
        let store = try makeStore(clock)
        let added = try store.addPriority(title: "Meditar", list: .today)
        #expect(added.repeatRule == RepeatRule.none)
        #expect(added.repeatSeriesID == nil)

        clock.advance(minutes: 5)
        let daily = try store.editPriority(added.id, {
            $0.repeatRule = .daily
            $0.repeatSeriesID = "other"
        })

        #expect(daily.repeatRule == .daily)
        #expect(daily.repeatSeriesID == nil)
        #expect(daily.updatedAt == localDate("2026-10-12T09:05:00"))
        #expect(try types(store, added.id) == [.created, .edited])
        #expect(try values("SELECT repeat_rule FROM priority", in: store.database) == ["daily"])

        try store.editPriority(added.id, { $0.repeatRule = .daily })
        #expect(try types(store, added.id) == [.created, .edited])
        try store.editPriority(added.id, { $0.repeatRule = .none })
        #expect(try types(store, added.id) == [.created, .edited, .edited])
    }
}
