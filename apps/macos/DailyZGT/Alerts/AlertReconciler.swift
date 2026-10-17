import Foundation

struct AlertReconcileResult: Equatable, Sendable {
    var authorization: AlertAuthorization
    var nextFireAt: Date?
}

@MainActor
final class AlertReconciler {
    private let store: AppStore
    private let center: any NotificationCenterClient

    init(store: AppStore, center: any NotificationCenterClient) {
        self.store = store
        self.center = center
    }

    @discardableResult
    func reconcile() async -> AlertReconcileResult {
        let authorization = await center.authorization()
        let pending = await center.pendingRequests()
        var result = AlertReconcileResult(authorization: authorization)
        do {
            let changes = AlertPlanner.changes(
                open: store.snapshot.open,
                rows: try store.alerts(status: .scheduled),
                now: store.now(),
                deliversAlerts: authorization == .authorized
            )
            try store.saveAlerts(changes.saved)
            result.nextFireAt = changes.scheduled.map(\.fireAt).min()

            let kept = Set(changes.scheduled.map(\.id))
            let stale = pending.map(\.id).filter { !kept.contains($0) && $0 != AlertRequest.testID }
            let unwanted = Set(stale).union(changes.cancelled).sorted()
            if !unwanted.isEmpty {
                await center.removePending(ids: unwanted)
            }
            if !changes.cancelled.isEmpty {
                await center.removeDelivered(ids: changes.cancelled)
            }

            guard authorization == .authorized else { return result }
            let pendingByID = Dictionary(pending.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            for row in changes.scheduled {
                guard let priority = store.priority(id: row.priorityID),
                      let request = AlertRequest(alert: row, priority: priority),
                      pendingByID[request.id] != request
                else {
                    continue
                }
                try await center.add(request)
            }
        } catch {
            AlertLog.logger.error("Reconcile failed: \(String(describing: error), privacy: .public)")
        }
        return result
    }
}
