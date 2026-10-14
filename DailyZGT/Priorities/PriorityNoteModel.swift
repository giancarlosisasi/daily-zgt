import Observation

enum PriorityNote {
    static func stored(from text: String) -> String {
        text.allSatisfy(\.isWhitespace) ? "" : text
    }

    static func isPresent(_ note: String) -> Bool {
        !stored(from: note).isEmpty
    }
}

@Observable
@MainActor
final class PriorityNoteModel {
    let priorityID: Priority.ID
    private(set) var text: String
    private(set) var hasUnsavedEdit = false
    private(set) var writeFailed = false

    @ObservationIgnored private let store: AppStore
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private let schedule: NotesSchedule
    @ObservationIgnored private var nextToken = 0

    init(
        store: AppStore,
        priorityID: Priority.ID,
        debounce: Duration = Theme.Notes.debounce,
        schedule: @escaping NotesSchedule = PriorityFlow.sleepSchedule
    ) {
        self.store = store
        self.priorityID = priorityID
        self.debounce = debounce
        self.schedule = schedule
        text = store.priority(id: priorityID)?.note ?? ""
    }

    var externalNote: String {
        store.priority(id: priorityID)?.note ?? ""
    }

    func edit(_ newText: String) {
        guard newText != text else { return }
        text = newText
        hasUnsavedEdit = true
        nextToken += 1
        let token = nextToken
        schedule(debounce) { [weak self] in
            guard let self, self.nextToken == token else { return }
            self.flush()
        }
    }

    func flush() {
        nextToken += 1
        guard hasUnsavedEdit else { return }
        guard let current = store.priority(id: priorityID) else {
            hasUnsavedEdit = false
            return
        }
        let note = PriorityNote.stored(from: text)
        guard note != current.note else {
            hasUnsavedEdit = false
            return
        }
        do {
            try store.editPriority(priorityID) { $0.note = note }
            hasUnsavedEdit = false
            writeFailed = false
        } catch {
            writeFailed = true
        }
    }

    func sync() {
        guard !hasUnsavedEdit else { return }
        let stored = externalNote
        if stored != PriorityNote.stored(from: text) {
            text = stored
        }
    }
}
