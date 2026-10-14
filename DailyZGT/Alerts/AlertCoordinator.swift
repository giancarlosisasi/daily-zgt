import AppKit
import Observation

struct AlertSubject: Equatable {
    let id: Priority.ID
    let title: String
    let dueAt: Date

    init?(_ priority: Priority) {
        guard let dueAt = priority.dueAt else { return nil }
        id = priority.id
        title = priority.title
        self.dueAt = dueAt
    }
}

@Observable
@MainActor
final class AlertCoordinator {
    static let permissionAskedKey = AppStateKey(name: "alert_permission_asked", defaultValue: false)
    static let testDelay: TimeInterval = 5
    static let wakeMargin: TimeInterval = 1

    private(set) var authorization = AlertAuthorization.notDetermined

    @ObservationIgnored private let store: AppStore
    @ObservationIgnored private let center: any NotificationCenterClient
    @ObservationIgnored private let reconciler: AlertReconciler
    @ObservationIgnored private let events: NotificationCenter
    @ObservationIgnored private let schedule: PrioritySchedule
    @ObservationIgnored private let onOpen: @MainActor (Priority.ID?) -> Void
    @ObservationIgnored private let onDayMayHaveChanged: @MainActor () -> Void
    @ObservationIgnored private var running: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var isForced = false
    @ObservationIgnored private var lastSubjects: [AlertSubject]?
    @ObservationIgnored private var wakeAt: Date?
    @ObservationIgnored private var wakeToken = 0

    init(
        store: AppStore,
        center: any NotificationCenterClient,
        events: NotificationCenter = .default,
        schedule: @escaping PrioritySchedule = PriorityFlow.sleepSchedule,
        onOpen: @escaping @MainActor (Priority.ID?) -> Void = { _ in },
        onDayMayHaveChanged: @escaping @MainActor () -> Void = {}
    ) {
        self.store = store
        self.center = center
        self.events = events
        self.schedule = schedule
        self.onOpen = onOpen
        self.onDayMayHaveChanged = onDayMayHaveChanged
        reconciler = AlertReconciler(store: store, center: center)
    }

    var alertsAreOff: Bool {
        switch authorization {
        case .authorized: false
        case .denied: true
        case .notDetermined: store.value(for: Self.permissionAskedKey)
        }
    }

    func start() {
        center.install(handler: self)
        for name in [NSApplication.didBecomeActiveNotification, .NSCalendarDayChanged] {
            _ = events.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.onDayMayHaveChanged()
                    self?.refresh()
                }
            }
        }
        observeStore()
        refresh()
    }

    func refresh() {
        requestRun(force: true)
    }

    func settle() async {
        while let running {
            await running.value
        }
    }

    func dueWasSet() {
        Task { await requestPermissionOnFirstDue() }
    }

    func bellWasPressed() {
        Task { await sendTestAlert() }
    }

    func requestPermissionOnFirstDue() async {
        guard !store.value(for: Self.permissionAskedKey) else { return }
        try? store.setValue(true, for: Self.permissionAskedKey)
        do {
            let granted = try await center.requestAuthorization()
            AlertLog.logger.notice("Permission request ended. granted: \(granted, privacy: .public)")
        } catch {
            AlertLog.logger.error("Permission request failed: \(String(describing: error), privacy: .public)")
        }
        refresh()
        await settle()
    }

    func sendTestAlert() async {
        await requestPermissionOnFirstDue()
        refresh()
        await settle()
        guard authorization == .authorized else { return }
        let fireAt = LocalTime.truncated(store.now().addingTimeInterval(Self.testDelay))
        do {
            try await center.add(.test(fireAt: fireAt))
        } catch {
            AlertLog.logger.error("Test alert failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func snooze(_ priority: Priority, acted alertID: PriorityAlert.ID) {
        guard priority.dueAt != nil else { return }
        var rows = [PriorityAlert(
            id: UUID().uuidString,
            priorityID: priority.id,
            kind: .snooze,
            fireAt: snoozeFireTime(),
            status: .scheduled
        )]
        if var acted = try? store.alert(id: alertID) {
            acted.status = .snoozed
            rows.append(acted)
        }
        do {
            try store.saveAlerts(rows)
            refresh()
        } catch {
            AlertLog.logger.error("Snooze failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func answerTestAlert(_ action: AlertAction) async {
        switch action {
        case .open:
            onOpen(nil)
        case .snooze:
            do {
                try await center.add(.test(fireAt: snoozeFireTime()))
            } catch {
                AlertLog.logger.error("Test alert failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private func snoozeFireTime() -> Date {
        LocalTime.truncated(store.now().addingTimeInterval(AlertPlanner.snoozeTime))
    }

    private func observeStore() {
        withObservationTracking {
            _ = store.snapshot
        } onChange: { [weak self] in
            MainActor.assumeIsolated {
                self?.observeStore()
                self?.requestRun(force: false)
            }
        }
    }

    private func requestRun(force: Bool) {
        generation += 1
        isForced = isForced || force
        guard running == nil else { return }
        running = Task {
            var seen: Int
            repeat {
                seen = generation
                await run()
            } while seen != generation
            running = nil
        }
    }

    private func run() async {
        let subjects = store.snapshot.open.compactMap(AlertSubject.init)
        guard isForced || subjects != lastSubjects else { return }
        isForced = false
        lastSubjects = subjects
        let result = await reconciler.reconcile()
        scheduleWake(at: result.nextFireAt)
        if result.authorization != authorization {
            authorization = result.authorization
            AlertLog.logger.notice("Authorization: \(String(describing: result.authorization), privacy: .public)")
        }
    }

    private func scheduleWake(at fireAt: Date?) {
        guard fireAt != wakeAt else { return }
        wakeAt = fireAt
        wakeToken += 1
        guard let fireAt else { return }
        let token = wakeToken
        let delay = max(fireAt.timeIntervalSince(store.now()), 0) + Self.wakeMargin
        schedule(.seconds(delay)) { [weak self] in
            guard let self, wakeToken == token else { return }
            wakeAt = nil
            refresh()
        }
    }
}

extension AlertCoordinator: AlertEventHandler {
    func alertWasPresented(id: String) {
        guard var alert = try? store.alert(id: id), alert.status == .scheduled else { return }
        alert.status = .delivered
        try? store.saveAlerts([alert])
    }

    func alertWasAnswered(_ response: AlertResponse) async {
        guard let id = response.priorityID else {
            await answerTestAlert(response.action)
            return
        }
        guard let priority = store.priority(id: id), !priority.isDone else { return }
        switch response.action {
        case .open:
            onOpen(id)
        case .snooze:
            snooze(priority, acted: response.alertID)
            await settle()
        }
    }
}
