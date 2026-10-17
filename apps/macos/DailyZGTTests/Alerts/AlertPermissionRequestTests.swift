import Foundation
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct AlertPermissionRequestTests {
    let clock = TestClock("2026-10-12T10:24:00")
    let center = FakeNotificationCenter(status: .notDetermined)
    let wake = ScheduleRecorder()

    private func started(_ store: AppStore) async -> AlertCoordinator {
        let alerts = AlertCoordinator(store: store, center: center, events: NotificationCenter(), schedule: wake.schedule)
        alerts.start()
        await alerts.settle()
        return alerts
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<2000 where !condition() {
            await Task.yield()
        }
    }

    private func drain() async {
        for _ in 0..<100 {
            await Task.yield()
        }
    }

    private func askedValues(_ store: AppStore) throws -> [String] {
        try values("SELECT value FROM app_state WHERE key = 'alert_permission_asked'", in: store.database)
    }

    private func submitDueFromTheForm(_ store: AppStore, title: String) throws -> Priority {
        var form = NewPriorityForm()
        form.open()
        form.draft.title = title
        form.draft.dueAt = localDate("2026-10-12T16:00:00")
        return try #require(try form.submit(to: store, list: .today))
    }

    @Test
    func theFirstDueFromTheFormAsksForThePermission() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        let added = try submitDueFromTheForm(store, title: "Enviar el reporte")
        #expect(added.dueAt != nil)
        #expect(center.requestCount == 0)

        alerts.dueWasSet()
        await waitUntil { alerts.authorization == .authorized }

        #expect(center.requestCount == 1)
        #expect(alerts.authorization == .authorized)
        #expect(try askedValues(store) == ["true"])
    }

    @Test
    func theFirstDueFromTheDetailAsksForThePermission() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        let plain = try store.addPriority(title: "Ordenar el escritorio", list: .today)
        try PriorityDetailActions(store: store, id: plain.id).setDue(localDate("2026-10-12T17:00:00"))
        #expect(center.requestCount == 0)

        alerts.dueWasSet()
        await waitUntil { alerts.authorization == .authorized }

        #expect(center.requestCount == 1)
        #expect(try askedValues(store) == ["true"])
    }

    @Test
    func aSecondDueFromTheFormDoesNotAskAgain() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        _ = try submitDueFromTheForm(store, title: "Enviar el reporte")
        alerts.dueWasSet()
        await waitUntil { alerts.authorization == .authorized }

        _ = try submitDueFromTheForm(store, title: "Llamar a Ana")
        alerts.dueWasSet()
        await drain()

        #expect(center.requestCount == 1)
    }

    @Test
    func aDueFromTheDetailAfterTheFormDoesNotAskAgain() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        _ = try submitDueFromTheForm(store, title: "Enviar el reporte")
        alerts.dueWasSet()
        await waitUntil { alerts.authorization == .authorized }

        let plain = try store.addPriority(title: "Ordenar el escritorio", list: .today)
        try PriorityDetailActions(store: store, id: plain.id).setDue(localDate("2026-10-12T17:00:00"))
        alerts.dueWasSet()
        await drain()

        #expect(center.requestCount == 1)
    }

    @Test
    func twoCallsAtOnceAskOneTime() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)

        alerts.dueWasSet()
        alerts.dueWasSet()
        await waitUntil { alerts.authorization == .authorized }
        await drain()

        #expect(center.requestCount == 1)
    }

    @Test
    func aDueThatTheAppAskedAboutInAnEarlierRunDoesNotAsk() async throws {
        let store = try makeStore(clock)
        try store.setValue(true, for: AlertCoordinator.permissionAskedKey)
        let alerts = await started(store)

        alerts.dueWasSet()
        await drain()

        #expect(center.requestCount == 0)
    }

    @Test
    func theBellAsksWhenTheAppNeverAsked() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        #expect(try askedValues(store).isEmpty)

        alerts.bellWasPressed()
        await waitUntil { !center.added.isEmpty }

        #expect(center.requestCount == 1)
        #expect(try askedValues(store) == ["true"])
    }

    @Test
    func theBellSendsTheTestAlertWhenThePermissionIsGranted() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)

        alerts.bellWasPressed()
        await waitUntil { !center.added.isEmpty }

        let sent = try #require(center.added.first)
        #expect(center.added.count == 1)
        #expect(sent.id == AlertRequest.testID)
        #expect(sent.priorityID == nil)
        #expect(sent.title == AlertCopy.overdue)
        #expect(sent.body == AlertCopy.testBody)
        #expect(sent.fireAt == LocalTime.truncated(clock.date.addingTimeInterval(AlertCoordinator.testDelay)))
        #expect(alerts.authorization == .authorized)
    }

    @Test
    func theBellSendsNothingWhenThePermissionIsDenied() async throws {
        center.answer = .deny
        let store = try makeStore(clock)
        let alerts = await started(store)

        alerts.bellWasPressed()
        await waitUntil { alerts.authorization == .denied }
        await drain()

        #expect(center.requestCount == 1)
        #expect(center.added.isEmpty)
        #expect(alerts.alertsAreOff)
    }

    @Test
    func theBellSendsNothingWhenTheRequestFails() async throws {
        center.answer = .fail
        let store = try makeStore(clock)
        let alerts = await started(store)

        alerts.bellWasPressed()
        await waitUntil { alerts.authorization == .denied }
        await drain()

        #expect(center.added.isEmpty)
    }

    @Test
    func theBellDoesNotAskAgainAfterTheAppAsked() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        alerts.dueWasSet()
        await waitUntil { alerts.authorization == .authorized }

        alerts.bellWasPressed()
        await waitUntil { !center.added.isEmpty }

        #expect(center.requestCount == 1)
        #expect(center.added.map(\.id) == [AlertRequest.testID])
    }

    @Test
    func theBellSendsNothingWhenThePermissionWasDeniedInAnEarlierRun() async throws {
        center.status = .denied
        let store = try makeStore(clock)
        try store.setValue(true, for: AlertCoordinator.permissionAskedKey)
        let alerts = await started(store)

        alerts.bellWasPressed()
        await drain()

        #expect(center.requestCount == 0)
        #expect(center.added.isEmpty)
    }
}
