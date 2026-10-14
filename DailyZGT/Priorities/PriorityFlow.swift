import Foundation
import Observation

typealias PrioritySchedule = @MainActor (Duration, @escaping @MainActor () -> Void) -> Void

struct PendingUndo: Equatable {
    let priorityID: Priority.ID
    let title: String
    let token: Int
    let startedAt: Date
    let lifetime: Duration

    func remainingFraction(at now: Date) -> Double {
        let total = Double(lifetime.components.seconds) + Double(lifetime.components.attoseconds) / 1e18
        guard total > 0 else { return 0 }
        return min(max(1 - now.timeIntervalSince(startedAt) / total, 0), 1)
    }
}

extension SubtaskProgress {
    var openCount: Int { total - done }

    var ratioLabel: String? {
        total > 0 ? "\(done)/\(total)" : nil
    }

    var openSubtasksLabel: String? {
        switch openCount {
        case ..<1: nil
        case 1: "Queda 1 subtarea abierta."
        default: "Quedan \(openCount) subtareas abiertas."
        }
    }
}

@Observable
@MainActor
final class PriorityFlow {
    private(set) var confirmingID: Priority.ID?
    private(set) var undo: PendingUndo?
    private(set) var highlightedID: Priority.ID?
    private(set) var scrollTargetID: Priority.ID?
    private(set) var writeFailed = false
    private(set) var expansion = SubtaskExpansion()
    private(set) var leavingIDs: Set<Priority.ID> = []

    @ObservationIgnored private let store: AppStore
    @ObservationIgnored private let schedule: PrioritySchedule
    @ObservationIgnored private let undoLifetime: Duration
    @ObservationIgnored private let highlightLifetime: Duration
    @ObservationIgnored private var nextToken = 0
    @ObservationIgnored private var nextHighlightToken = 0

    init(
        store: AppStore,
        undoLifetime: Duration = Theme.Timing.undoLifetime,
        highlightLifetime: Duration = Theme.Timing.highlightLifetime,
        schedule: @escaping PrioritySchedule = PriorityFlow.sleepSchedule
    ) {
        self.store = store
        self.undoLifetime = undoLifetime
        self.highlightLifetime = highlightLifetime
        self.schedule = schedule
    }

    static let sleepSchedule: PrioritySchedule = { duration, action in
        Task { @MainActor in
            try? await Task.sleep(for: duration)
            action()
        }
    }

    func isConfirming(_ id: Priority.ID) -> Bool {
        confirmingID == id
    }

    func isExpanded(_ id: Priority.ID) -> Bool {
        expansion.isExpanded(id)
    }

    func toggleSubtasks(for id: Priority.ID) {
        expansion.toggle(id)
    }

    func isLeaving(_ id: Priority.ID) -> Bool {
        leavingIDs.contains(id)
    }

    func toggleConfirmation(for id: Priority.ID) {
        guard !isLeaving(id) else { return }
        confirmingID = confirmingID == id ? nil : id
    }

    func cancelConfirmation() {
        if let confirmingID, isLeaving(confirmingID) { return }
        confirmingID = nil
    }

    func confirmDone(_ id: Priority.ID, leaving delay: Duration = .zero) {
        guard !isLeaving(id) else { return }
        guard delay > .zero else {
            completeDone(id)
            return
        }
        leavingIDs.insert(id)
        schedule(delay) { [weak self] in
            self?.finishLeaving(id)
        }
    }

    private func finishLeaving(_ id: Priority.ID) {
        guard leavingIDs.remove(id) != nil else { return }
        guard store.priority(id: id) != nil else { return }
        completeDone(id)
    }

    private func completeDone(_ id: Priority.ID) {
        do {
            let done = try store.markDone(id)
            writeFailed = false
            if confirmingID == id {
                confirmingID = nil
            }
            startUndo(for: done)
        } catch {
            writeFailed = true
        }
    }

    func undoDone() {
        guard let pending = undo else { return }
        do {
            try store.restorePriority(pending.priorityID)
            writeFailed = false
            undo = nil
            flash(pending.priorityID)
        } catch {
            writeFailed = true
        }
    }

    func restore(_ id: Priority.ID) {
        do {
            try store.restorePriority(id)
            writeFailed = false
            if undo?.priorityID == id {
                undo = nil
            }
            flash(id)
        } catch {
            writeFailed = true
        }
    }

    func delete(_ id: Priority.ID) {
        do {
            try store.deletePriority(id)
            leavingIDs.remove(id)
            writeFailed = false
            if undo?.priorityID == id {
                undo = nil
            }
        } catch {
            writeFailed = true
        }
    }

    func flash(_ id: Priority.ID) {
        highlightedID = id
        scrollTargetID = id
        nextHighlightToken += 1
        let token = nextHighlightToken
        schedule(highlightLifetime) { [weak self] in
            if self?.nextHighlightToken == token {
                self?.highlightedID = nil
                self?.scrollTargetID = nil
            }
        }
    }

    func scrollWasHandled(_ id: Priority.ID) {
        if scrollTargetID == id {
            scrollTargetID = nil
        }
    }

    private func startUndo(for priority: Priority) {
        nextToken += 1
        let pending = PendingUndo(
            priorityID: priority.id,
            title: priority.title,
            token: nextToken,
            startedAt: store.now(),
            lifetime: undoLifetime
        )
        undo = pending
        schedule(undoLifetime) { [weak self] in
            if self?.undo?.token == pending.token {
                self?.undo = nil
            }
        }
    }
}
