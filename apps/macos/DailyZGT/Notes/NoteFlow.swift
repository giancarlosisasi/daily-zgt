import Foundation
import Observation

struct PendingNoteUndo: TimedUndo {
    let note: NoteItem
    let title: String
    let token: Int
    let startedAt: Date
    let lifetime: Duration
}

@Observable
@MainActor
final class NoteFlow {
    private(set) var undo: PendingNoteUndo?
    private(set) var writeFailed = false

    @ObservationIgnored private let store: AppStore
    @ObservationIgnored private let schedule: PrioritySchedule
    @ObservationIgnored private let undoLifetime: Duration
    @ObservationIgnored private var nextToken = 0

    init(
        store: AppStore,
        undoLifetime: Duration = Theme.Timing.undoLifetime,
        schedule: @escaping PrioritySchedule = PriorityFlow.sleepSchedule
    ) {
        self.store = store
        self.undoLifetime = undoLifetime
        self.schedule = schedule
    }

    func delete(_ id: NoteItem.ID) {
        do {
            let deleted = try store.deleteNote(id)
            writeFailed = false
            guard !NoteBody.isEmpty(deleted.body) else { return }
            startUndo(for: deleted)
        } catch {
            writeFailed = true
        }
    }

    func undoDelete() {
        guard let pending = undo else { return }
        do {
            try store.restoreNote(pending.note)
            writeFailed = false
            undo = nil
        } catch {
            writeFailed = true
        }
    }

    private func startUndo(for note: NoteItem) {
        nextToken += 1
        let pending = PendingNoteUndo(
            note: note,
            title: NoteSummary.make(note.body).title,
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
