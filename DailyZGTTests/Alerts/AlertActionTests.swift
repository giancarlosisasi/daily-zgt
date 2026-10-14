import Foundation
import Testing
@testable import DailyZGT

@MainActor
final class OpenRecorder {
    private(set) var opened: [Priority.ID?] = []

    func record(_ id: Priority.ID?) {
        opened.append(id)
    }
}

@Suite
@MainActor
struct AlertActionTests {
    let clock = TestClock("2026-10-12T10:00:00")
    let center = FakeNotificationCenter()
    let recorder = OpenRecorder()
    let wake = ScheduleRecorder()

    private func started(_ store: AppStore) async -> AlertCoordinator {
        let alerts = AlertCoordinator(
            store: store,
            center: center,
            events: NotificationCenter(),
            schedule: wake.schedule
        ) { [recorder] id in
            recorder.record(id)
        }
        alerts.start()
        await alerts.settle()
        return alerts
    }

    private func briefWithAlerts(_ store: AppStore, _ alerts: AlertCoordinator) async throws -> (Priority, [PriorityAlert]) {
        let brief = try store.addPriority(
            title: "Terminar el brief",
            list: .week,
            dueAt: localDate("2026-10-12T10:30:00")
        )
        await alerts.settle()
        return (brief, try store.alerts())
    }

    private func fire(_ alert: PriorityAlert, in alerts: AlertCoordinator) {
        clock.date = alert.fireAt.addingTimeInterval(60)
        center.pending[alert.id] = nil
        alerts.alertWasPresented(id: alert.id)
    }

    private func answer(_ action: AlertAction, alert: String, priority: Priority.ID?) -> AlertResponse {
        AlertResponse(alertID: alert, priorityID: priority, action: action)
    }

    @Test
    func theStartInstallsTheHandlerOfTheAlertEvents() async throws {
        let alerts = await started(try makeStore(clock))
        #expect(center.handler === alerts)
    }

    @Test
    func openShowsThePriority() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        let (brief, rows) = try await briefWithAlerts(store, alerts)

        await alerts.alertWasAnswered(answer(.open, alert: rows[0].id, priority: brief.id))

        #expect(recorder.opened == [brief.id])
        #expect(try store.alerts() == rows)
    }

    @Test
    func openOnADonePriorityDoesNothing() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        let (brief, rows) = try await briefWithAlerts(store, alerts)
        try store.markDone(brief.id)
        await alerts.settle()

        await alerts.alertWasAnswered(answer(.open, alert: rows[0].id, priority: brief.id))

        #expect(recorder.opened.isEmpty)
    }

    @Test
    func openOnAPriorityThatIsGoneDoesNothing() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        let (brief, rows) = try await briefWithAlerts(store, alerts)
        try store.deletePriority(brief.id)
        await alerts.settle()

        await alerts.alertWasAnswered(answer(.open, alert: rows[0].id, priority: brief.id))

        #expect(recorder.opened.isEmpty)
    }

    @Test
    func openOnTheTestAlertShowsThePanelWithNoPriority() async throws {
        let alerts = await started(try makeStore(clock))
        await alerts.alertWasAnswered(answer(.open, alert: AlertRequest.testID, priority: nil))
        #expect(recorder.opened == [nil])
    }

    @Test
    func snoozeAddsOneAlertIn15MinAndSetsTheActedAlertToSnoozed() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        let (brief, rows) = try await briefWithAlerts(store, alerts)
        #expect(rows.map(\.kind) == [.atDue])

        clock.date = localDate("2026-10-12T10:31:10")
        center.pending.removeAll()
        alerts.alertWasPresented(id: rows[0].id)
        await alerts.alertWasAnswered(answer(.snooze, alert: rows[0].id, priority: brief.id))

        let after = try store.alerts()
        #expect(after.map(\.kind) == [.atDue, .snooze])
        #expect(after.map(\.status) == [.snoozed, .scheduled])
        #expect(after[1].fireAt == localDate("2026-10-12T10:46:10"))
        #expect(after[1].priorityID == brief.id)
        #expect(center.pending == [after[1].id: AlertRequest(
            id: after[1].id,
            title: "Prioridad vencida",
            body: "Terminar el brief",
            fireAt: localDate("2026-10-12T10:46:10"),
            priorityID: brief.id
        )])
        #expect(recorder.opened.isEmpty)
    }

    @Test
    func aSnoozeBeforeTheDueSaysTheMinutesThatAreLeft() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        let brief = try store.addPriority(title: "Terminar el brief", list: .today, dueAt: localDate("2026-10-12T11:00:00"))
        await alerts.settle()
        let before = try #require(try store.alerts().first { $0.kind == .before30m })

        clock.date = localDate("2026-10-12T10:31:00")
        alerts.alertWasPresented(id: before.id)
        await alerts.alertWasAnswered(answer(.snooze, alert: before.id, priority: brief.id))

        let snooze = try #require(try store.alerts().first { $0.kind == .snooze })
        #expect(snooze.fireAt == localDate("2026-10-12T10:46:00"))
        #expect(center.pending[snooze.id]?.title == "Vence en 14 min")
        #expect(try store.alert(id: before.id)?.status == .snoozed)
        #expect(try store.alerts(status: .scheduled).map(\.kind) == [.snooze, .atDue])
    }

    @Test
    func theSnoozeStaysWhenTheAlertsAreReconciledAgain() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        let (brief, rows) = try await briefWithAlerts(store, alerts)
        fire(rows[0], in: alerts)
        await alerts.alertWasAnswered(answer(.snooze, alert: rows[0].id, priority: brief.id))
        let after = try store.alerts()
        let added = center.added.count
        #expect(after.map(\.status) == [.snoozed, .scheduled])

        alerts.refresh()
        await alerts.settle()
        try store.editPriority(brief.id) { $0.title = "Terminar el brief hoy" }
        await alerts.settle()

        #expect(try store.alerts() == after)
        #expect(center.added.count == added + 1)
        #expect(center.pending.values.map(\.body) == ["Terminar el brief hoy"])
    }

    @Test
    func snoozeOnADonePriorityDoesNothing() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        let (brief, rows) = try await briefWithAlerts(store, alerts)
        try store.markDone(brief.id)
        await alerts.settle()
        let before = try store.alerts()

        await alerts.alertWasAnswered(answer(.snooze, alert: rows[0].id, priority: brief.id))

        #expect(try store.alerts() == before)
        #expect(center.pending.isEmpty)
    }

    @Test
    func snoozeOnAPriorityThatIsGoneDoesNothing() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        let (brief, rows) = try await briefWithAlerts(store, alerts)
        try store.deletePriority(brief.id)
        await alerts.settle()

        await alerts.alertWasAnswered(answer(.snooze, alert: rows[0].id, priority: brief.id))

        #expect(try store.alerts().isEmpty)
        #expect(center.pending.isEmpty)
    }

    @Test
    func snoozeOnAPriorityWithNoDueDoesNothing() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        let (brief, rows) = try await briefWithAlerts(store, alerts)
        try store.editPriority(brief.id) { $0.dueAt = nil }
        await alerts.settle()

        await alerts.alertWasAnswered(answer(.snooze, alert: rows[0].id, priority: brief.id))

        #expect(try store.alerts().map(\.kind) == [.atDue])
        #expect(try store.alerts().map(\.status) == [.cancelled])
    }

    @Test
    func doneCancelsTheSnooze() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        let (brief, rows) = try await briefWithAlerts(store, alerts)
        fire(rows[0], in: alerts)
        await alerts.alertWasAnswered(answer(.snooze, alert: rows[0].id, priority: brief.id))
        #expect(center.pending.count == 1)

        try store.markDone(brief.id)
        await alerts.settle()

        #expect(try store.alerts().map(\.kind) == [.atDue, .snooze])
        #expect(try store.alerts().map(\.status) == [.snoozed, .cancelled])
        #expect(center.pending.isEmpty)
    }

    @Test
    func snoozeOnTheTestAlertSendsItAgainIn15MinWithNoRow() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)

        await alerts.alertWasAnswered(answer(.snooze, alert: AlertRequest.testID, priority: nil))

        #expect(center.pending == ["test-alert": .test(fireAt: localDate("2026-10-12T10:15:00"))])
        #expect(try store.alerts().isEmpty)
        #expect(recorder.opened.isEmpty)
    }

    @Test
    func anAlertThatMacOSShowsWhileTheAppRunsBecomesDelivered() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        let (_, rows) = try await briefWithAlerts(store, alerts)

        alerts.alertWasPresented(id: rows[0].id)
        #expect(try store.alerts().map(\.status) == [.delivered])

        alerts.alertWasPresented(id: rows[0].id)
        alerts.alertWasPresented(id: AlertRequest.testID)
        alerts.alertWasPresented(id: "missing")
        #expect(try store.alerts().map(\.status) == [.delivered])
    }

    @Test
    func aCancelledAlertThatMacOSShowsStaysCancelled() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        let (brief, rows) = try await briefWithAlerts(store, alerts)
        try store.markDone(brief.id)
        await alerts.settle()

        alerts.alertWasPresented(id: rows[0].id)
        #expect(try store.alerts().map(\.status) == [.cancelled])
    }

    @Test
    func openWithThePanelStateShowsTheListOfThePriorityAndHighlightsIt() async throws {
        let store = try makeStore(clock)
        let schedule = ScheduleRecorder()
        let state = PanelState(store: store, priorityFlow: PriorityFlow(store: store, schedule: schedule.schedule))
        let alerts = AlertCoordinator(
            store: store,
            center: center,
            events: NotificationCenter(),
            schedule: wake.schedule
        ) { id in
            state.showInList(id)
        }
        alerts.start()
        let (brief, rows) = try await briefWithAlerts(store, alerts)
        state.select(tab: .notes)

        await alerts.alertWasAnswered(answer(.open, alert: rows[0].id, priority: brief.id))

        #expect(state.tab == .priorities)
        #expect(state.scope == .week)
        #expect(state.priorityFlow.highlightedID == brief.id)
        #expect(schedule.entries.map(\.delay) == [.milliseconds(1400)])
    }
}
