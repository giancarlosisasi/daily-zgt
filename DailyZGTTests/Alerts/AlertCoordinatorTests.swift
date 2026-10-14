import AppKit
import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct AlertCoordinatorTests {
    let clock = TestClock("2026-10-12T10:00:00")
    let center = FakeNotificationCenter()
    let events = NotificationCenter()
    let wake = ScheduleRecorder()

    private func started(_ store: AppStore) async -> AlertCoordinator {
        let alerts = AlertCoordinator(store: store, center: center, events: events, schedule: wake.schedule)
        alerts.start()
        await alerts.settle()
        return alerts
    }

    @Test
    func theStartPlansTheAlertsOfThePrioritiesThatExist() async throws {
        let store = try makeStore(clock)
        try store.addPriority(title: "Terminar el brief", list: .today, dueAt: localDate("2026-10-12T12:00:00"))

        _ = await started(store)

        let rows = try store.alerts()
        #expect(rows.map(\.kind) == [.before30m, .atDue])
        #expect(Set(center.pending.keys) == Set(rows.map(\.id)))
        #expect(center.requestCount == 0)
    }

    @Test
    func aNewDuePlansItsAlerts() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        #expect(try store.alerts().isEmpty)

        try store.addPriority(title: "Terminar el brief", list: .today, dueAt: localDate("2026-10-12T12:00:00"))
        await alerts.settle()

        #expect(try store.alerts().map(\.kind) == [.before30m, .atDue])
        #expect(center.pending.count == 2)
    }

    @Test(.timeLimit(.minutes(1)))
    func aWriteThatSkipsTheStorePlansItsAlerts() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)

        try await nextChange(of: store) {
            try execute(
                """
                INSERT INTO priority (id, title, level, list, due_at, position, created_at, updated_at)
                VALUES ('p1', 'From sqlite3', 'high', 'today', '2026-10-12T12:00:00', 1,
                        '2026-10-12T09:00:00', '2026-10-12T09:00:00')
                """,
                in: store.database
            )
        }
        await alerts.settle()

        let rows = try store.alerts()
        #expect(rows.map(\.priorityID) == ["p1", "p1"])
        #expect(rows.map(\.fireAt) == [localDate("2026-10-12T11:30:00"), localDate("2026-10-12T12:00:00")])
        #expect(center.pending.values.map(\.body) == ["From sqlite3", "From sqlite3"])
    }

    @Test
    func aStoreChangeThatDoesNotTouchThePlanDoesNotReadMacOS() async throws {
        let store = try makeStore(clock)
        try store.addPriority(title: "Terminar el brief", list: .today, dueAt: localDate("2026-10-12T12:00:00"))
        let alerts = await started(store)
        let reads = center.pendingReads

        try store.saveNote("Hablar con Ana.", scope: .day)
        try store.addPriority(title: "No due", list: .week)
        await alerts.settle()

        #expect(center.pendingReads == reads)
        #expect(center.added.count == 2)
    }

    @Test
    func aDueChangeInTheStoreMovesTheAlerts() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        let brief = try store.addPriority(title: "Terminar el brief", list: .today, dueAt: localDate("2026-10-12T12:00:00"))
        await alerts.settle()
        let ids = try store.alerts().map(\.id)

        try store.editPriority(brief.id) { $0.dueAt = localDate("2026-10-12T17:00:00") }
        await alerts.settle()

        let rows = try store.alerts()
        #expect(rows.map(\.id) == ids)
        #expect(rows.map(\.fireAt) == [localDate("2026-10-12T16:30:00"), localDate("2026-10-12T17:00:00")])
        #expect(center.pending.values.map(\.fireAt).sorted() == rows.map(\.fireAt))
    }

    @Test
    func doneCancelsTheAlertsAndRestorePlansThemAgain() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        let brief = try store.addPriority(title: "Terminar el brief", list: .today, dueAt: localDate("2026-10-12T12:00:00"))
        await alerts.settle()

        try store.markDone(brief.id)
        await alerts.settle()
        #expect(try store.alerts().map(\.status) == [.cancelled, .cancelled])
        #expect(center.pending.isEmpty)

        try store.restorePriority(brief.id)
        await alerts.settle()
        #expect(try store.alerts(status: .scheduled).map(\.kind) == [.before30m, .atDue])
        #expect(center.pending.count == 2)
    }

    @Test
    func deleteRemovesTheRequests() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        let brief = try store.addPriority(title: "Terminar el brief", list: .today, dueAt: localDate("2026-10-12T12:00:00"))
        await alerts.settle()
        #expect(center.pending.count == 2)

        try store.deletePriority(brief.id)
        await alerts.settle()
        #expect(try store.alerts().isEmpty)
        #expect(center.pending.isEmpty)
    }

    @Test(.timeLimit(.minutes(1)))
    func aDueChangeAndADoneFromAnotherConnectionMoveAndCancelTheAlerts() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        try store.addPriority(title: "Terminar el brief", list: .today, dueAt: localDate("2026-10-12T12:00:00"))
        await alerts.settle()

        try await nextChange(of: store) {
            try execute("UPDATE priority SET due_at = '2026-10-12T18:00:00'", in: store.database)
        }
        await alerts.settle()
        #expect(try store.alerts().map(\.fireAt) == [localDate("2026-10-12T17:30:00"), localDate("2026-10-12T18:00:00")])
        #expect(try store.alerts().map(\.status) == [.scheduled, .scheduled])

        try await nextChange(of: store) {
            try execute("UPDATE priority SET done_at = '2026-10-12T10:00:00'", in: store.database)
        }
        await alerts.settle()
        #expect(try store.alerts().map(\.status) == [.cancelled, .cancelled])
        #expect(center.pending.isEmpty)
    }

    @Test
    func theDayChangeReconcilesTheAlerts() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        try store.addPriority(title: "Terminar el brief", list: .today, dueAt: localDate("2026-10-12T12:00:00"))
        await alerts.settle()

        clock.date = localDate("2026-10-13T00:00:00")
        center.pending.removeAll()
        events.post(name: .NSCalendarDayChanged, object: nil)
        await alerts.settle()

        #expect(try store.alerts().map(\.status) == [.delivered, .delivered])
        #expect(center.added.count == 2)
    }

    @Test
    func theCoordinatorWakesOneSecondAfterTheNextFireTime() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        #expect(wake.entries.isEmpty)

        try store.addPriority(title: "Terminar el brief", list: .today, dueAt: localDate("2026-10-12T12:00:00"))
        await alerts.settle()

        #expect(wake.entries.map(\.delay) == [.seconds(5401)])
    }

    @Test
    func theWakeMarksTheAlertAsDeliveredAndPlansTheNextWake() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        try store.addPriority(title: "Terminar el brief", list: .today, dueAt: localDate("2026-10-12T12:00:00"))
        await alerts.settle()
        let rows = try store.alerts()

        clock.date = localDate("2026-10-12T11:30:01")
        center.pending[rows[0].id] = nil
        wake.fire(0)
        await alerts.settle()

        #expect(try store.alerts().map(\.status) == [.delivered, .scheduled])
        #expect(wake.entries.map(\.delay) == [.seconds(5401), .seconds(1800)])

        clock.date = localDate("2026-10-12T12:00:01")
        center.pending[rows[1].id] = nil
        wake.fire(1)
        await alerts.settle()

        #expect(try store.alerts().map(\.status) == [.delivered, .delivered])
        #expect(wake.entries.count == 2)
        #expect(center.added.count == 2)
    }

    @Test
    func aWakeOfAnOldPlanDoesNothing() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        let brief = try store.addPriority(title: "Terminar el brief", list: .today, dueAt: localDate("2026-10-12T12:00:00"))
        await alerts.settle()
        try store.editPriority(brief.id) { $0.dueAt = localDate("2026-10-12T17:00:00") }
        await alerts.settle()
        #expect(wake.entries.map(\.delay) == [.seconds(5401), .seconds(23401)])
        let reads = center.pendingReads

        wake.fire(0)
        await alerts.settle()

        #expect(center.pendingReads == reads)
    }

    @Test
    func aRunWithTheSameNextFireTimePlansNoNewWake() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        let brief = try store.addPriority(title: "Terminar el brief", list: .today, dueAt: localDate("2026-10-12T12:00:00"))
        await alerts.settle()

        try store.editPriority(brief.id) { $0.title = "Terminar el brief hoy" }
        await alerts.settle()
        alerts.refresh()
        await alerts.settle()

        #expect(wake.entries.count == 1)
    }

    @Test
    func twoRunsInARowDoNothingTheSecondTime() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        try store.addPriority(title: "Terminar el brief", list: .today, dueAt: localDate("2026-10-12T12:00:00"))
        await alerts.settle()
        let rows = try store.alerts()
        let pending = center.pending

        alerts.refresh()
        await alerts.settle()
        alerts.refresh()
        await alerts.settle()

        #expect(try store.alerts() == rows)
        #expect(center.pending == pending)
        #expect(center.added.count == 2)
        #expect(center.removedPending.isEmpty)
    }

    @Test
    func theBellSendsOneTestAlertAFewSecondsLaterAndAsksFirst() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)

        await alerts.sendTestAlert()

        #expect(center.requestCount == 1)
        #expect(center.pending == ["test-alert": AlertRequest(
            id: "test-alert",
            title: "Prioridad vencida",
            body: "Revisa tu lista de hoy",
            fireAt: localDate("2026-10-12T10:00:05"),
            priorityID: nil
        )])
        #expect(try store.alerts().isEmpty)
    }

    @Test
    func theBellDoesNotAskWhenTheAppAskedBefore() async throws {
        let store = try makeStore(clock)
        try store.setValue(true, for: AlertCoordinator.permissionAskedKey)
        let alerts = await started(store)

        await alerts.sendTestAlert()

        #expect(center.requestCount == 0)
        #expect(center.pending.keys.map { $0 } == ["test-alert"])
    }

    @Test
    func aSecondPressReplacesTheTestAlert() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)

        await alerts.sendTestAlert()
        clock.date.addTimeInterval(2)
        await alerts.sendTestAlert()

        #expect(center.pending.count == 1)
        #expect(center.pending["test-alert"]?.fireAt == localDate("2026-10-12T10:00:07"))
    }

    @Test
    func theBellSendsNothingWhenTheAlertsAreOff() async throws {
        center.status = .denied
        center.answer = .deny
        let store = try makeStore(clock)
        let alerts = await started(store)

        await alerts.sendTestAlert()

        #expect(center.requestCount == 1)
        #expect(center.added.isEmpty)
        #expect(alerts.alertsAreOff)
    }

    @Test
    func theTestAlertStaysWhenTheAlertsAreReconciled() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        await alerts.sendTestAlert()

        try store.addPriority(title: "Terminar el brief", list: .today, dueAt: localDate("2026-10-12T12:00:00"))
        await alerts.settle()

        #expect(center.pending["test-alert"] != nil)
        #expect(center.pending.count == 3)
    }

    @Test
    func rendersTheFooterWithTheBell() throws {
        let footer = PanelFooter(summary: "2 de 5 hechas hoy") { TestAlertButton {} }
        let url = try Screenshot.writeHosted(footer.panelChrome(), named: "footer-bell")
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func rendersTheFooterWithTheBellWhenTheAlertsAreOff() throws {
        let footer = PanelFooter(summary: "2 de 5 hechas hoy") { TestAlertButton(alertsOff: true) {} }
        let url = try Screenshot.writeHosted(footer.panelChrome(), named: "footer-bell-off")
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func theBellDoesNotChangeTheHeightOfTheFooter() {
        let plain = PanelFooter(summary: "2 de 5 hechas hoy")
        let withBell = PanelFooter(summary: "2 de 5 hechas hoy") { TestAlertButton {} }
        let width = Theme.Panel.width
        #expect(
            NSHostingView(rootView: withBell.frame(width: width)).fittingSize.height
                == NSHostingView(rootView: plain.frame(width: width)).fittingSize.height
        )
    }
}
