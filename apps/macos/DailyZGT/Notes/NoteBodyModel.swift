import Observation

typealias NotesSchedule = PrioritySchedule

enum NoteBody {
    static func isEmpty(_ body: String) -> Bool {
        body.allSatisfy(\.isWhitespace)
    }
}

@Observable
@MainActor
final class NoteBodyModel {
    let noteID: NoteItem.ID
    private(set) var text: String
    private(set) var hasUnsavedEdit = false
    private(set) var writeFailed = false

    @ObservationIgnored private let store: AppStore
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private let schedule: NotesSchedule
    @ObservationIgnored private var nextToken = 0

    init(
        store: AppStore,
        noteID: NoteItem.ID,
        debounce: Duration = Theme.Notes.debounce,
        schedule: @escaping NotesSchedule = PriorityFlow.sleepSchedule
    ) {
        self.store = store
        self.noteID = noteID
        self.debounce = debounce
        self.schedule = schedule
        text = store.noteIncludingDeleted(id: noteID)?.body ?? ""
    }

    var externalBody: String {
        store.noteIncludingDeleted(id: noteID)?.body ?? ""
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
        guard let current = store.note(id: noteID) else {
            hasUnsavedEdit = false
            return
        }
        guard text != current.body else {
            hasUnsavedEdit = false
            return
        }
        do {
            try store.editNote(noteID, body: text)
            hasUnsavedEdit = false
            writeFailed = false
        } catch {
            writeFailed = true
        }
    }

    func sync() {
        guard !hasUnsavedEdit else { return }
        let stored = externalBody
        if stored != text {
            text = stored
        }
    }

    func leave() {
        flush()
        guard !hasUnsavedEdit, let current = store.note(id: noteID), NoteBody.isEmpty(current.body) else { return }
        try? store.deleteNoteForever(noteID)
    }
}
