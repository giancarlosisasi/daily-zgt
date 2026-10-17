import AppKit
import Foundation
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct RepeatCoordinatorTests {
    let clock = TestClock("2026-10-12T09:00:00")
    let center = FakeNotificationCenter()
    let events = NotificationCenter()
    let wake = ScheduleRecorder()

    private func started(_ store: AppStore) async -> (RepeatCoordinator, AlertCoordinator) {
        let repeats = RepeatCoordinator(store: store)
        let alerts = AlertCoordinator(
            store: store,
            center: center,
            events: events,
            schedule: wake.schedule,
            onDayMayHaveChanged: { repeats.run() }
        )
        repeats.start()
        alerts.start()
        await settle(repeats, alerts)
        return (repeats, alerts)
    }

    private func settle(_ repeats: RepeatCoordinator, _ alerts: AlertCoordinator) async {
        await repeats.settle()
        await alerts.settle()
        await repeats.settle()
    }

    private func doneDaily(_ store: AppStore, due: String? = nil) throws -> Priority {
        let added = try addDaily(store, due: due)
        return try store.markDone(added.id)
    }

    @Test
    func theStartAddsTheCopyOfASeriesThatIsReady() async throws {
        let store = try makeStore(clock)
        let source = try doneDaily(store)
        clock.date = localDate("2026-10-13T07:00:00")

        _ = await started(store)

        let open = store.openPriorities(in: .today)
        #expect(open.map(\.title) == ["Meditar"])
        #expect(open.map(\.seriesID) == [source.id])
        #expect(try store.events(of: try #require(open.first).id).map(\.type) == [.created])
    }

    @Test
    func theStartAddsNothingForAPriorityDoneToday() async throws {
        let store = try makeStore(clock)
        _ = try doneDaily(store)

        _ = await started(store)

        #expect(store.openPriorities(in: .today).isEmpty)
        #expect(try values("SELECT COUNT(*) FROM priority", in: store.database) == [1])
    }

    @Test
    func theDayChangeAddsTheCopyAndTheAlertReconcilerPlansItsAlerts() async throws {
        let store = try makeStore(clock)
        let source = try doneDaily(store, due: "2026-10-12T23:00:00")
        let (repeats, alerts) = await started(store)
        #expect(store.openPriorities(in: .today).isEmpty)
        #expect(center.pending.isEmpty)

        clock.date = localDate("2026-10-13T00:00:00")
        events.post(name: .NSCalendarDayChanged, object: nil)
        await settle(repeats, alerts)

        let copy = try #require(store.openPriorities(in: .today).first)
        #expect(store.openPriorities(in: .today).count == 1)
        #expect(copy.id != source.id)
        #expect(copy.dueAt == localDate("2026-10-13T23:00:00"))

        let rows = try store.alerts(status: .scheduled)
        #expect(rows.map(\.priorityID) == [copy.id, copy.id])
        #expect(rows.map(\.kind) == [.before30m, .atDue])
        #expect(rows.map(\.fireAt) == [localDate("2026-10-13T22:30:00"), localDate("2026-10-13T23:00:00")])
        #expect(Set(center.pending.keys) == Set(rows.map(\.id)))
        #expect(center.pending.values.map(\.body) == ["Meditar", "Meditar"])
    }

    @Test
    func aSecondDayChangeOnTheSameDayAddsNothing() async throws {
        let store = try makeStore(clock)
        _ = try doneDaily(store, due: "2026-10-12T23:00:00")
        let (repeats, alerts) = await started(store)

        clock.date = localDate("2026-10-13T00:00:00")
        events.post(name: .NSCalendarDayChanged, object: nil)
        await settle(repeats, alerts)
        events.post(name: .NSCalendarDayChanged, object: nil)
        events.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        repeats.run()
        repeats.run()
        await settle(repeats, alerts)

        #expect(store.openPriorities(in: .today).count == 1)
        #expect(try values("SELECT COUNT(*) FROM priority", in: store.database) == [2])
        #expect(try store.alerts(status: .scheduled).count == 2)
        #expect(center.pending.count == 2)
        #expect(try openCopiesBySeries(store) == [1])
    }

    @Test
    func theAppThatBecomesActiveOnALaterDayAddsOneCopy() async throws {
        let store = try makeStore(clock)
        _ = try doneDaily(store)
        let (repeats, alerts) = await started(store)

        clock.date = localDate("2026-10-16T08:00:00")
        events.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        await settle(repeats, alerts)

        #expect(store.openPriorities(in: .today).count == 1)
        #expect(store.openPriorities(in: .today).first?.createdAt == localDate("2026-10-16T08:00:00"))
    }

    @Test
    func aStoreChangeThatMakesASeriesReadyAddsTheCopyAtOnce() async throws {
        let store = try makeStore(clock)
        let plain = try store.addPriority(title: "Leer", list: .today)
        try store.markDone(plain.id)
        clock.date = localDate("2026-10-13T07:00:00")
        let (repeats, alerts) = await started(store)
        #expect(store.openPriorities(in: .today).isEmpty)

        try store.editPriority(plain.id, { $0.repeatRule = .daily })
        await settle(repeats, alerts)

        #expect(store.openPriorities(in: .today).map(\.title) == ["Leer"])
        #expect(store.openPriorities(in: .today).map(\.seriesID) == [plain.id])
    }

    @Test(.timeLimit(.minutes(1)))
    func aWriteThatSkipsTheStoreAddsTheCopy() async throws {
        let store = try makeStore(clock)
        let plain = try store.addPriority(title: "Leer", list: .today)
        try store.markDone(plain.id)
        clock.date = localDate("2026-10-13T07:00:00")
        let (repeats, alerts) = await started(store)

        try await nextChange(of: store) {
            try execute("UPDATE priority SET repeat_rule = 'daily'", in: store.database)
        }
        await settle(repeats, alerts)

        #expect(store.openPriorities(in: .today).map(\.title) == ["Leer"])
        #expect(try openCopiesBySeries(store) == [1])
    }

    @Test
    func aChangeThatMakesNoSeriesReadyAddsNothing() async throws {
        let store = try makeStore(clock)
        let open = try addDaily(store)
        let (repeats, alerts) = await started(store)

        try store.saveNote("Hablar con Ana.", scope: .day)
        try store.addSubtask(to: open.id, title: "Respirar")
        try store.markDone(open.id)
        await settle(repeats, alerts)

        #expect(store.openPriorities(in: .today).isEmpty)
        #expect(try values("SELECT COUNT(*) FROM priority", in: store.database) == [1])
    }

    @Test
    func aRestoreThroughTheFlowLeavesOneOpenCopyOfTheSeries() async throws {
        let store = try makeStore(clock)
        let source = try doneDaily(store)
        clock.date = localDate("2026-10-13T07:00:00")
        let (repeats, alerts) = await started(store)
        let copy = try #require(store.openPriorities(in: .today).first)
        let flow = PriorityFlow(store: store, schedule: ScheduleRecorder().schedule)

        flow.restore(source.id)
        await settle(repeats, alerts)

        #expect(flow.writeFailed == false)
        #expect(flow.highlightedID == source.id)
        #expect(store.priority(id: copy.id) == nil)
        #expect(store.openPriorities(in: .today).map(\.id) == [source.id])
        #expect(try openCopiesBySeries(store) == [1])
    }

    @Test
    func doneAndUndoOnTheSameDayAddNoCopy() async throws {
        let store = try makeStore(clock)
        let open = try addDaily(store)
        let (repeats, alerts) = await started(store)
        let flow = PriorityFlow(store: store, schedule: ScheduleRecorder().schedule)

        flow.confirmDone(open.id)
        await settle(repeats, alerts)
        #expect(store.openPriorities(in: .today).isEmpty)

        flow.undoDone()
        await settle(repeats, alerts)
        #expect(store.openPriorities(in: .today).map(\.id) == [open.id])
        #expect(try values("SELECT COUNT(*) FROM priority", in: store.database) == [1])
    }
}
