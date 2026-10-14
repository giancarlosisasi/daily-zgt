import AppKit
import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct AlertPermissionTests {
    let clock = TestClock("2026-10-12T10:24:00")
    let center = FakeNotificationCenter(status: .notDetermined)
    let events = NotificationCenter()
    let wake = ScheduleRecorder()

    private func started(_ store: AppStore) async -> AlertCoordinator {
        let alerts = AlertCoordinator(store: store, center: center, events: events, schedule: wake.schedule)
        alerts.start()
        await alerts.settle()
        return alerts
    }

    private func askedValues(_ store: AppStore) throws -> [String] {
        try values("SELECT value FROM app_state WHERE key = 'alert_permission_asked'", in: store.database)
    }

    @Test
    func theAppDoesNotAskAtStart() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)
        #expect(center.requestCount == 0)
        #expect(alerts.authorization == .notDetermined)
        #expect(!alerts.alertsAreOff)
        #expect(try askedValues(store).isEmpty)
    }

    @Test
    func theFirstDueAsksOneTimeAndKeepsTheFact() async throws {
        let store = try makeStore(clock)
        let alerts = await started(store)

        await alerts.requestPermissionOnFirstDue()
        #expect(center.requestCount == 1)
        #expect(alerts.authorization == .authorized)
        #expect(!alerts.alertsAreOff)
        #expect(try askedValues(store) == ["true"])

        await alerts.requestPermissionOnFirstDue()
        #expect(center.requestCount == 1)
    }

    @Test
    func aNewCoordinatorOnTheSameDatabaseDoesNotAskAgain() async throws {
        let store = try makeStore(clock)
        await started(store).requestPermissionOnFirstDue()
        let next = await started(AppStore(database: store.database))
        await next.requestPermissionOnFirstDue()
        #expect(center.requestCount == 1)
    }

    @Test
    func aDeniedPermissionTurnsTheAlertsOff() async throws {
        center.answer = .deny
        let alerts = await started(try makeStore(clock))
        await alerts.requestPermissionOnFirstDue()
        #expect(alerts.authorization == .denied)
        #expect(alerts.alertsAreOff)
    }

    @Test
    func aRequestThatFailsCountsAsAskedAndTurnsTheAlertsOff() async throws {
        center.answer = .fail
        let store = try makeStore(clock)
        let alerts = await started(store)
        await alerts.requestPermissionOnFirstDue()
        #expect(alerts.alertsAreOff)
        #expect(try askedValues(store) == ["true"])
        await alerts.requestPermissionOnFirstDue()
        #expect(center.requestCount == 1)
    }

    @Test
    func aRequestWithNoAnswerTurnsTheAlertsOff() async throws {
        center.answer = .noAnswer
        let alerts = await started(try makeStore(clock))
        await alerts.requestPermissionOnFirstDue()
        #expect(alerts.authorization == .notDetermined)
        #expect(alerts.alertsAreOff)
    }

    @Test
    func aPermissionThatIsDeniedAtStartTurnsTheAlertsOff() async throws {
        center.status = .denied
        let alerts = await started(try makeStore(clock))
        #expect(alerts.alertsAreOff)
        #expect(center.requestCount == 0)
    }

    @Test
    func theAppReadsThePermissionAgainWhenItBecomesActive() async throws {
        center.status = .denied
        let alerts = await started(try makeStore(clock))
        #expect(alerts.alertsAreOff)

        center.status = .authorized
        events.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        await alerts.settle()
        #expect(alerts.authorization == .authorized)
        #expect(!alerts.alertsAreOff)
    }

    @Test
    func rendersTheFormWithTheAlertsOff() throws {
        var form = NewPriorityForm()
        form.open()
        form.draft.title = "Enviar el reporte de QA"
        form.draft.level = .high
        form.draft.dueAt = localDate("2026-10-12T16:00:00")
        let view = NewPriorityFormView(form: .constant(form), now: clock.date, alertsOff: true, onSubmit: {})
        let url = try Screenshot.writeHosted(view.panelChrome(), named: "alerts-off-form")
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func rendersTheDetailWithTheAlertsOff() async throws {
        center.status = .denied
        let store = try makeStore(clock)
        let alerts = await started(store)
        let state = PanelState(store: store)
        let brief = try store.addPriority(
            title: "Terminar el brief de Tailwind v4",
            level: .high,
            list: .today,
            dueAt: localDate("2026-10-12T11:00:00")
        )
        let view = PriorityDetailView(priority: brief)
            .environment(store)
            .environment(state)
            .environment(alerts)
        let url = try Screenshot.writeHosted(view.panelChrome(), named: "alerts-off-detail")
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func aPriorityWithNoDueShowsNoAlertsOffLineInTheDetailBox() throws {
        let store = try makeStore(clock)
        let plain = try store.addPriority(title: "Ordenar el escritorio", list: .week)
        let off = PriorityDetailBox(priority: plain, now: clock.date, alertsOff: true, onLevel: { _ in }, onDue: { _ in }, onList: { _ in })
        let on = PriorityDetailBox(priority: plain, now: clock.date, onLevel: { _ in }, onDue: { _ in }, onList: { _ in })
        let width = Theme.Panel.width
        let offHeight = NSHostingView(rootView: off.frame(width: width)).fittingSize.height
        let onHeight = NSHostingView(rootView: on.frame(width: width)).fittingSize.height
        #expect(offHeight == onHeight)
    }
}
