import Foundation

struct WantedAlert: Equatable, Sendable {
    var priorityID: Priority.ID
    var kind: AlertKind
    var fireAt: Date
}

struct AlertChanges: Equatable, Sendable {
    var saved: [PriorityAlert] = []
    var scheduled: [PriorityAlert] = []
    var cancelled: [PriorityAlert.ID] = []
}

enum AlertPlanner {
    static let leadTime: TimeInterval = 30 * 60
    static let snoozeTime: TimeInterval = 15 * 60

    static func wanted(for priorities: [Priority], now: Date) -> [WantedAlert] {
        priorities.flatMap { priority -> [WantedAlert] in
            guard !priority.isDone, let due = priority.dueAt else { return [] }
            return [
                WantedAlert(priorityID: priority.id, kind: .before30m, fireAt: due.addingTimeInterval(-leadTime)),
                WantedAlert(priorityID: priority.id, kind: .atDue, fireAt: due),
            ].filter { $0.fireAt > now }
        }
    }

    static func changes(
        open priorities: [Priority],
        rows: [PriorityAlert],
        now: Date,
        deliversAlerts: Bool = true,
        makeID: () -> String = { UUID().uuidString }
    ) -> AlertChanges {
        var changes = AlertChanges()
        var unmet = wanted(for: priorities, now: now)
        let withDue = Set(priorities.filter { !$0.isDone && $0.dueAt != nil }.map(\.id))
        for row in rows where row.status == .scheduled {
            var next = row
            if row.fireAt <= now {
                next.status = deliversAlerts ? .delivered : .cancelled
            } else if row.kind == .snooze {
                if !withDue.contains(row.priorityID) {
                    next.status = .cancelled
                }
            } else if let index = unmet.firstIndex(where: { $0.priorityID == row.priorityID && $0.kind == row.kind }) {
                next.fireAt = unmet.remove(at: index).fireAt
            } else {
                next.status = .cancelled
            }
            if next != row {
                changes.saved.append(next)
            }
            if next.status == .scheduled {
                changes.scheduled.append(next)
            } else if next.status == .cancelled {
                changes.cancelled.append(next.id)
            }
        }
        for alert in unmet {
            let row = PriorityAlert(
                id: makeID(),
                priorityID: alert.priorityID,
                kind: alert.kind,
                fireAt: alert.fireAt,
                status: .scheduled
            )
            changes.saved.append(row)
            changes.scheduled.append(row)
        }
        return changes
    }
}
