import Foundation
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct AlertReconcilerTests {
    let clock = TestClock("2026-10-12T10:00:00")
    let center = FakeNotificationCenter()

    private func makeReconciler(_ store: AppStore) -> AlertReconciler {
        AlertReconciler(store: store, center: center)
    }

    private func addBrief(to store: AppStore, due: String = "2026-10-12T12:00:00") throws -> Priority {
        try store.addPriority(title: "Terminar el brief", level: .high, list: .today, dueAt: localDate(due))
    }

    @Test
    func aDuePlansTwoRowsAndTwoRequests() async throws {
        let store = try makeStore(clock)
        let brief = try addBrief(to: store)

        await makeReconciler(store).reconcile()

        let rows = try store.alerts()
        #expect(rows.map(\.kind) == [.before30m, .atDue])
        #expect(rows.map(\.fireAt) == [localDate("2026-10-12T11:30:00"), localDate("2026-10-12T12:00:00")])
        #expect(rows.map(\.status) == [.scheduled, .scheduled])
        #expect(rows.map(\.priorityID) == [brief.id, brief.id])
        #expect(center.pending[rows[0].id] == AlertRequest(
            id: rows[0].id,
            title: "Vence en 30 min",
            body: "Terminar el brief",
            fireAt: localDate("2026-10-12T11:30:00"),
            priorityID: brief.id
        ))
        #expect(center.pending[rows[1].id] == AlertRequest(
            id: rows[1].id,
            title: "Prioridad vencida",
            body: "Terminar el brief",
            fireAt: localDate("2026-10-12T12:00:00"),
            priorityID: brief.id
        ))
        #expect(center.pending.count == 2)
    }

    @Test
    func aDueIn29MinPlansOnlyTheAlertAtTheDue() async throws {
        let store = try makeStore(clock)
        _ = try addBrief(to: store, due: "2026-10-12T10:29:00")
        await makeReconciler(store).reconcile()
        #expect(try store.alerts().map(\.kind) == [.atDue])
        #expect(center.pending.count == 1)
    }

    @Test
    func aPriorityWithNoDuePlansNothing() async throws {
        let store = try makeStore(clock)
        try store.addPriority(title: "No due", list: .today)
        await makeReconciler(store).reconcile()
        #expect(try store.alerts().isEmpty)
        #expect(center.added.isEmpty)
    }

    @Test
    func theSecondRunDoesNothing() async throws {
        let store = try makeStore(clock)
        _ = try addBrief(to: store)
        let reconciler = makeReconciler(store)

        await reconciler.reconcile()
        let rows = try store.alerts()
        let pending = center.pending
        await reconciler.reconcile()

        #expect(try store.alerts() == rows)
        #expect(center.pending == pending)
        #expect(center.added.count == 2)
        #expect(center.removedPending.isEmpty)
        #expect(center.removedDelivered.isEmpty)
    }

    private func expectNoChangeOnTheNextRun(_ store: AppStore, _ reconciler: AlertReconciler) async throws {
        let rows = try store.alerts()
        let pending = center.pending
        let added = center.added.count
        let removedPending = center.removedPending.count
        let removedDelivered = center.removedDelivered.count
        await reconciler.reconcile()
        #expect(try store.alerts() == rows)
        #expect(center.pending == pending)
        #expect(center.added.count == added)
        #expect(center.removedPending.count == removedPending)
        #expect(center.removedDelivered.count == removedDelivered)
    }

    @Test
    func aDueChangeMovesTheRowsAndTheRequests() async throws {
        let store = try makeStore(clock)
        let brief = try addBrief(to: store)
        let reconciler = makeReconciler(store)
        await reconciler.reconcile()
        let before = try store.alerts()

        try store.editPriority(brief.id) { $0.dueAt = localDate("2026-10-12T17:00:00") }
        await reconciler.reconcile()

        let rows = try store.alerts()
        #expect(Set(rows.map(\.id)) == Set(before.map(\.id)))
        #expect(rows.map(\.kind) == [.before30m, .atDue])
        #expect(rows.map(\.fireAt) == [localDate("2026-10-12T16:30:00"), localDate("2026-10-12T17:00:00")])
        #expect(rows.map(\.status) == [.scheduled, .scheduled])
        #expect(center.pending[rows[0].id]?.fireAt == localDate("2026-10-12T16:30:00"))
        #expect(center.pending[rows[1].id]?.fireAt == localDate("2026-10-12T17:00:00"))
        #expect(center.pending.count == 2)
        try await expectNoChangeOnTheNextRun(store, reconciler)
    }

    @Test
    func aDueThatMovesInside30MinCancelsTheAlertBefore() async throws {
        let store = try makeStore(clock)
        let brief = try addBrief(to: store)
        let reconciler = makeReconciler(store)
        await reconciler.reconcile()

        try store.editPriority(brief.id) { $0.dueAt = localDate("2026-10-12T10:20:00") }
        await reconciler.reconcile()

        let rows = try store.alerts()
        #expect(rows.map(\.kind) == [.atDue, .before30m])
        #expect(rows.map(\.status) == [.scheduled, .cancelled])
        #expect(rows[0].fireAt == localDate("2026-10-12T10:20:00"))
        #expect(center.pending.keys.map { $0 } == [rows[0].id])
        try await expectNoChangeOnTheNextRun(store, reconciler)
    }

    @Test
    func aDueThatIsRemovedCancelsTheAlerts() async throws {
        let store = try makeStore(clock)
        let brief = try addBrief(to: store)
        let reconciler = makeReconciler(store)
        await reconciler.reconcile()

        try store.editPriority(brief.id) { $0.dueAt = nil }
        await reconciler.reconcile()

        #expect(try store.alerts().map(\.status) == [.cancelled, .cancelled])
        #expect(center.pending.isEmpty)
        try await expectNoChangeOnTheNextRun(store, reconciler)
    }

    @Test
    func doneCancelsTheAlertsAndRestorePlansThemAgain() async throws {
        let store = try makeStore(clock)
        let brief = try addBrief(to: store)
        let reconciler = makeReconciler(store)
        await reconciler.reconcile()
        let first = try store.alerts().map(\.id)

        try store.markDone(brief.id)
        await reconciler.reconcile()

        #expect(try store.alerts().map(\.status) == [.cancelled, .cancelled])
        #expect(center.pending.isEmpty)
        #expect(center.removedPending == [first.sorted()])
        #expect(center.removedDelivered.map { $0.sorted() } == [first.sorted()])
        try await expectNoChangeOnTheNextRun(store, reconciler)

        try store.restorePriority(brief.id)
        await reconciler.reconcile()

        let scheduled = try store.alerts(status: .scheduled)
        #expect(scheduled.map(\.kind) == [.before30m, .atDue])
        #expect(Set(scheduled.map(\.id)).isDisjoint(with: first))
        #expect(try store.alerts(status: .cancelled).count == 2)
        #expect(Set(center.pending.keys) == Set(scheduled.map(\.id)))
        try await expectNoChangeOnTheNextRun(store, reconciler)
    }

    @Test
    func deleteRemovesTheRowsAndTheRequests() async throws {
        let store = try makeStore(clock)
        let brief = try addBrief(to: store)
        let reconciler = makeReconciler(store)
        await reconciler.reconcile()

        try store.deletePriority(brief.id)
        await reconciler.reconcile()

        #expect(try store.alerts().isEmpty)
        #expect(center.pending.isEmpty)
        try await expectNoChangeOnTheNextRun(store, reconciler)
    }

    @Test
    func aScheduledRowWithAPastFireTimeBecomesDelivered() async throws {
        let store = try makeStore(clock)
        _ = try addBrief(to: store)
        let reconciler = makeReconciler(store)
        await reconciler.reconcile()
        let rows = try store.alerts()

        clock.advance(minutes: 95)
        center.pending[rows[0].id] = nil
        await reconciler.reconcile()

        #expect(try store.alerts().map(\.status) == [.delivered, .scheduled])
        #expect(center.removedDelivered.isEmpty)
        #expect(center.pending.keys.map { $0 } == [rows[1].id])
        try await expectNoChangeOnTheNextRun(store, reconciler)

        clock.advance(minutes: 30)
        center.pending[rows[1].id] = nil
        await reconciler.reconcile()
        #expect(try store.alerts().map(\.status) == [.delivered, .delivered])
        #expect(center.added.count == 2)
        try await expectNoChangeOnTheNextRun(store, reconciler)
    }

    @Test
    func withNoPermissionARowWithAPastFireTimeBecomesCancelled() async throws {
        center.status = .denied
        let store = try makeStore(clock)
        _ = try addBrief(to: store)
        let reconciler = makeReconciler(store)
        await reconciler.reconcile()

        clock.advance(minutes: 95)
        await reconciler.reconcile()

        #expect(try store.alerts().map(\.status) == [.cancelled, .scheduled])
        #expect(center.added.isEmpty)
        try await expectNoChangeOnTheNextRun(store, reconciler)
    }

    @Test
    func aRequestThatTheTableDoesNotHaveIsRemovedAndTheTestAlertStays() async throws {
        let store = try makeStore(clock)
        _ = try addBrief(to: store)
        let reconciler = makeReconciler(store)
        let unknown = AlertRequest(
            id: "unknown",
            title: "Prioridad vencida",
            body: "Old",
            fireAt: localDate("2026-10-12T13:00:00"),
            priorityID: "gone"
        )
        center.pending["unknown"] = unknown
        center.pending[AlertRequest.testID] = .test(fireAt: localDate("2026-10-12T10:00:05"))

        await reconciler.reconcile()

        #expect(center.removedPending == [["unknown"]])
        #expect(center.removedDelivered.isEmpty)
        #expect(center.pending["unknown"] == nil)
        #expect(center.pending[AlertRequest.testID] != nil)
        #expect(center.pending.count == 3)
        try await expectNoChangeOnTheNextRun(store, reconciler)
    }

    @Test(.timeLimit(.minutes(1)))
    func aChangeFromAnotherConnectionMovesTheRowsOnTheNextRun() async throws {
        let store = try makeStore(clock)
        _ = try addBrief(to: store)
        let reconciler = makeReconciler(store)
        await reconciler.reconcile()

        try await nextChange(of: store) {
            try execute("UPDATE priority SET due_at = '2026-10-12T18:00:00'", in: store.database)
        }
        await reconciler.reconcile()
        #expect(try store.alerts().map(\.fireAt) == [localDate("2026-10-12T17:30:00"), localDate("2026-10-12T18:00:00")])

        try await nextChange(of: store) {
            try execute("UPDATE priority SET done_at = '2026-10-12T10:00:00'", in: store.database)
        }
        await reconciler.reconcile()
        #expect(try store.alerts().map(\.status) == [.cancelled, .cancelled])
        #expect(center.pending.isEmpty)
    }

    @Test
    func withNoPermissionTheRowsStayAsThePlanAndNoRequestIsAdded() async throws {
        center.status = .denied
        let store = try makeStore(clock)
        _ = try addBrief(to: store)
        let reconciler = makeReconciler(store)

        #expect(await reconciler.reconcile().authorization == .denied)
        #expect(try store.alerts().map(\.status) == [.scheduled, .scheduled])
        #expect(center.added.isEmpty)

        center.status = .authorized
        #expect(await reconciler.reconcile().authorization == .authorized)
        #expect(Set(center.pending.keys) == Set(try store.alerts().map(\.id)))
    }

    @Test
    func theResultHasTheNextFireTimeOfTheScheduledRows() async throws {
        let store = try makeStore(clock)
        let reconciler = makeReconciler(store)
        #expect(await reconciler.reconcile().nextFireAt == nil)

        let brief = try addBrief(to: store)
        try store.addPriority(title: "Later", list: .week, dueAt: localDate("2026-10-12T18:00:00"))
        #expect(await reconciler.reconcile().nextFireAt == localDate("2026-10-12T11:30:00"))

        clock.advance(minutes: 95)
        #expect(await reconciler.reconcile().nextFireAt == localDate("2026-10-12T12:00:00"))

        try store.markDone(brief.id)
        #expect(await reconciler.reconcile().nextFireAt == localDate("2026-10-12T17:30:00"))
    }

    @Test
    func aRequestThatMacOSLostIsAddedAgain() async throws {
        let store = try makeStore(clock)
        _ = try addBrief(to: store)
        let reconciler = makeReconciler(store)
        await reconciler.reconcile()
        let rows = try store.alerts()

        center.pending[rows[0].id] = nil
        await reconciler.reconcile()

        #expect(try store.alerts() == rows)
        #expect(Set(center.pending.keys) == Set(rows.map(\.id)))
        #expect(center.added.count == 3)
    }

    @Test
    func aTitleChangeReplacesTheBodyOfTheRequests() async throws {
        let store = try makeStore(clock)
        let brief = try addBrief(to: store)
        let reconciler = makeReconciler(store)
        await reconciler.reconcile()

        try store.editPriority(brief.id) { $0.title = "Terminar el brief de Tailwind v4" }
        await reconciler.reconcile()

        #expect(center.pending.values.map(\.body) == ["Terminar el brief de Tailwind v4", "Terminar el brief de Tailwind v4"])
        #expect(center.pending.count == 2)
        #expect(try store.alerts().count == 2)
    }

    @Test
    func anAddThatFailsKeepsTheRowsAndTheNextRunAddsTheRequests() async throws {
        center.addError = FakeCenterError()
        let store = try makeStore(clock)
        _ = try addBrief(to: store)
        let reconciler = makeReconciler(store)

        await reconciler.reconcile()
        #expect(try store.alerts().count == 2)
        #expect(center.pending.isEmpty)

        center.addError = nil
        await reconciler.reconcile()
        #expect(center.pending.count == 2)
        #expect(try store.alerts().count == 2)
    }
}
