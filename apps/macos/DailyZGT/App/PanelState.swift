import Observation

enum PanelTab: String, Codable, CaseIterable, Sendable {
    case priorities
    case notes
}

@Observable
@MainActor
final class PanelState {
    static let tabKey = AppStateKey(name: "open_tab", defaultValue: PanelTab.priorities)
    static let filterKey = AppStateKey<DueFilter?>(name: "due_filter", defaultValue: nil)
    static let noteScopeKey = AppStateKey<NoteScope?>(name: "note_scope", defaultValue: nil)
    static let noteFilterKey = AppStateKey<DueFilter?>(name: "note_filter", defaultValue: nil)
    static let legacyScopeKey = AppStateKey<PriorityList?>(name: "open_scope", defaultValue: nil)
    static let doneOpenKey = AppStateKey(name: "done_open", defaultValue: false)

    private(set) var tab: PanelTab
    private(set) var filter: DueFilter
    private(set) var noteFilter: DueFilter
    private(set) var openNoteID: NoteItem.ID?
    private(set) var focusNoteID: NoteItem.ID?
    private(set) var isDoneOpen: Bool
    private(set) var saveError: (any Error)?
    private(set) var openPriorityID: Priority.ID?
    private(set) var isSettingsOpen = false
    private(set) var isHistoryOpen = false
    private(set) var detailOpenedDone = false
    private(set) var detailReturnsToHistory = false

    @ObservationIgnored let priorityFlow: PriorityFlow
    @ObservationIgnored let noteFlow: NoteFlow
    @ObservationIgnored private var noteFlushes: [NoteItem.ID: @MainActor () -> Void] = [:]
    @ObservationIgnored let loginItem: LoginItemSettings
    @ObservationIgnored let shortcut: ShortcutSettings
    @ObservationIgnored private let store: AppStore

    init(
        store: AppStore,
        priorityFlow: PriorityFlow? = nil,
        noteFlow: NoteFlow? = nil,
        loginItem: LoginItemSettings? = nil,
        shortcut: ShortcutSettings? = nil
    ) {
        self.store = store
        self.priorityFlow = priorityFlow ?? PriorityFlow(store: store)
        self.noteFlow = noteFlow ?? NoteFlow(store: store)
        self.loginItem = loginItem ?? LoginItemSettings(service: InertLoginItemService())
        self.shortcut = shortcut ?? ShortcutSettings(service: InertHotkeyService())
        tab = store.value(for: Self.tabKey)
        let legacy = store.value(for: Self.legacyScopeKey)
        filter = store.value(for: Self.filterKey) ?? (legacy == .week ? .week : .today)
        noteFilter = DueFilter.noteStart(
            stored: store.value(for: Self.noteFilterKey),
            legacyScope: store.value(for: Self.noteScopeKey) ?? (legacy == .week ? .week : nil)
        )
        isDoneOpen = store.value(for: Self.doneOpenKey)
    }

    var detailPriority: Priority? {
        guard let id = openPriorityID, let priority = store.priority(id: id) else { return nil }
        guard !priority.isDone || detailOpenedDone else { return nil }
        return priority
    }

    var detailNote: NoteItem? {
        openNoteID.flatMap { store.note(id: $0) }
    }

    var page: PanelPage {
        if isSettingsOpen { return .settings }
        if isHistoryOpen { return .history }
        return .browse
    }

    func openDetail(_ id: Priority.ID) {
        guard let priority = store.priority(id: id) else { return }
        let fromHistory = isHistoryOpen
        priorityFlow.cancelConfirmation()
        closeSettings()
        closeHistory()
        select(tab: .priorities)
        let days = store.dueDays
        if !priority.isDone, !filter.includes(priority, days) {
            select(filter: DueFilter.home(for: priority, days))
        }
        openPriorityID = id
        detailOpenedDone = priority.isDone
        detailReturnsToHistory = fromHistory
    }

    func backFromDetail() {
        let toHistory = detailReturnsToHistory
        closeDetail()
        if toHistory {
            openHistory()
        }
    }

    func restoreFromDetail() {
        guard let id = openPriorityID else { return }
        priorityFlow.restore(id)
        guard !priorityFlow.writeFailed else { return }
        detailOpenedDone = false
        detailReturnsToHistory = false
    }

    func openSettings() {
        guard !isSettingsOpen else { return }
        closeDetail()
        closeNote()
        closeHistory()
        isSettingsOpen = true
        loginItem.settingsDidOpen()
        shortcut.refresh()
    }

    func openHistory() {
        guard !isHistoryOpen else { return }
        select(tab: .priorities)
        isHistoryOpen = true
    }

    func closeHistory() {
        isHistoryOpen = false
    }

    func closeSettings() {
        isSettingsOpen = false
    }

    func toggleSettings() {
        if isSettingsOpen {
            closeSettings()
        } else {
            openSettings()
        }
    }

    func showInList(_ id: Priority.ID?) {
        let priority = id.flatMap { store.priority(id: $0) }.flatMap { $0.isDone ? nil : $0 }
        select(tab: .priorities)
        let days = store.dueDays
        if let priority {
            if !filter.includes(priority, days) {
                select(filter: DueFilter.home(for: priority, days))
            }
        } else {
            select(filter: .today)
        }
        if let priority {
            priorityFlow.flash(priority.id)
        }
    }

    func closeDetail() {
        guard openPriorityID != nil else { return }
        openPriorityID = nil
        detailOpenedDone = false
        detailReturnsToHistory = false
        priorityFlow.cancelConfirmation()
    }

    func closeDetailIfGone() {
        if openPriorityID != nil, detailPriority == nil {
            closeDetail()
        }
    }

    func select(tab newTab: PanelTab) {
        closeSettings()
        closeHistory()
        closeDetail()
        closeNote()
        guard newTab != tab else { return }
        tab = newTab
        persist { try store.setValue(newTab, for: Self.tabKey) }
    }

    func select(filter newFilter: DueFilter) {
        let resolved = newFilter.resolved(store.dueDays)
        guard resolved != filter else { return }
        closeHistory()
        filter = resolved
        persist { try store.setValue(resolved, for: Self.filterKey) }
    }

    func step(by days: Int) {
        guard let next = filter.stepped(by: days, store.dueDays) else { return }
        select(filter: next)
    }

    func select(noteFilter newFilter: DueFilter) {
        let resolved = newFilter.resolved(store.dueDays)
        guard resolved != noteFilter else { return }
        noteFilter = resolved
        persist { try store.setValue(resolved, for: Self.noteFilterKey) }
    }

    func stepNotes(by days: Int) {
        guard let next = noteFilter.noteStepped(by: days, store.dueDays) else { return }
        select(noteFilter: next)
    }

    func openNote(_ id: NoteItem.ID) {
        guard store.note(id: id) != nil else { return }
        closeSettings()
        closeHistory()
        if tab != .notes {
            select(tab: .notes)
        }
        openNoteID = id
        focusNoteID = nil
    }

    func createNote() {
        let days = store.dueDays
        if let span = noteFilter.span(days), !span.contains(days.now) {
            select(noteFilter: .today)
        }
        do {
            let note = try store.addNote()
            saveError = nil
            openNote(note.id)
            focusNoteID = note.id
        } catch {
            saveError = error
        }
    }

    func registerNoteFlush(_ id: NoteItem.ID, _ flush: @escaping @MainActor () -> Void) {
        noteFlushes[id] = flush
    }

    func unregisterNoteFlush(_ id: NoteItem.ID) {
        noteFlushes[id] = nil
    }

    func deleteNote(_ id: NoteItem.ID) {
        if openNoteID == id {
            noteFlushes[id]?()
        }
        noteFlow.delete(id)
        if openNoteID == id {
            openNoteID = nil
        }
    }

    func closeNote() {
        guard openNoteID != nil else { return }
        openNoteID = nil
        focusNoteID = nil
    }

    func closeNoteIfGone() {
        if openNoteID != nil, detailNote == nil {
            closeNote()
        }
    }

    func setTodayLimit(_ isOn: Bool) {
        persist { try store.setValue(isOn, for: TodayLimit.key) }
    }

    func setMenuBarTitle(_ isOn: Bool) {
        persist { try store.setValue(isOn, for: MenuBarTitle.key) }
    }

    func toggleDone() {
        let next = !isDoneOpen
        isDoneOpen = next
        persist { try store.setValue(next, for: Self.doneOpenKey) }
    }

    private func persist(_ write: () throws -> Void) {
        do {
            try write()
            saveError = nil
        } catch {
            saveError = error
        }
    }
}
