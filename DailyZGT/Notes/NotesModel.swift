import Observation

typealias NotesSchedule = PrioritySchedule

@Observable
@MainActor
final class NotesModel {
    private(set) var scope: NoteScope
    private(set) var period: String
    private(set) var text: String
    private(set) var hasUnsavedEdit = false
    private(set) var writeFailed = false

    @ObservationIgnored private let store: AppStore
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private let schedule: NotesSchedule
    @ObservationIgnored private var nextToken = 0

    init(
        store: AppStore,
        scope: NoteScope,
        debounce: Duration = Theme.Notes.debounce,
        schedule: @escaping NotesSchedule = PriorityFlow.sleepSchedule
    ) {
        self.store = store
        self.scope = scope
        self.debounce = debounce
        self.schedule = schedule
        let period = store.period(scope)
        self.period = period
        text = store.noteBody(scope, period: period)
    }

    var externalBody: String {
        store.noteBody(scope, period: period)
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
        guard text != store.noteBody(scope, period: period) else {
            hasUnsavedEdit = false
            return
        }
        do {
            try store.saveNote(text, scope: scope, period: period)
            hasUnsavedEdit = false
            writeFailed = false
        } catch {
            writeFailed = true
        }
    }

    func select(scope newScope: NoteScope) {
        guard newScope != scope else { return }
        flush()
        scope = newScope
        reload()
    }

    func sync() {
        if store.period(scope) != period {
            flush()
            reload()
            return
        }
        guard !hasUnsavedEdit else { return }
        let stored = store.noteBody(scope, period: period)
        if stored != text {
            text = stored
        }
    }

    private func reload() {
        nextToken += 1
        period = store.period(scope)
        text = store.noteBody(scope, period: period)
        hasUnsavedEdit = false
    }
}
