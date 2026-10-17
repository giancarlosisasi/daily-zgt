import Foundation
import Observation
import os

@MainActor
final class RepeatCoordinator {
    static let logger = Logger(subsystem: "com.giancarlosisasi.dailyzgt", category: "repeat")

    private let store: AppStore
    private var pending: Task<Void, Never>?

    init(store: AppStore) {
        self.store = store
    }

    func start() {
        observeStore()
        run()
    }

    func run() {
        let snapshot = store.snapshot
        let ready = RepeatPlanner.copies(
            of: snapshot.open + snapshot.done,
            subtasks: snapshot.subtasks,
            now: store.now()
        )
        guard !ready.isEmpty else { return }
        do {
            let added = try store.addRepeatCopies()
            Self.logger.notice("Repeat copies added: \(added.count, privacy: .public)")
        } catch {
            Self.logger.error("Repeat copies failed: \(String(describing: error), privacy: .public)")
        }
    }

    func settle() async {
        while let pending {
            await pending.value
        }
    }

    private func observeStore() {
        withObservationTracking {
            _ = store.snapshot
        } onChange: { [weak self] in
            MainActor.assumeIsolated {
                self?.observeStore()
                self?.runAfterTheChange()
            }
        }
    }

    private func runAfterTheChange() {
        guard pending == nil else { return }
        pending = Task { [weak self] in
            self?.pending = nil
            self?.run()
        }
    }
}
