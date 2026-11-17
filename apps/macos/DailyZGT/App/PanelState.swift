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
    static let legacyScopeKey = AppStateKey<PriorityList?>(name: "open_scope", defaultValue: nil)
    static let doneOpenKey = AppStateKey(name: "done_open", defaultValue: false)

    private(set) var tab: PanelTab
    private(set) var filter: DueFilter
    private(set) var noteScope: NoteScope
    private(set) var isDoneOpen: Bool
    private(set) var saveError: (any Error)?
    private(set) var openPriorityID: Priority.ID?
    private(set) var isSettingsOpen = false
    private(set) var isHistoryOpen = false
    private(set) var detailOpenedDone = false
    private(set) var detailReturnsToHistory = false

    @ObservationIgnored let priorityFlow: PriorityFlow
    @ObservationIgnored let loginItem: LoginItemSettings
    @ObservationIgnored let shortcut: ShortcutSettings
    @ObservationIgnored private let store: AppStore

    init(
        store: AppStore,
        priorityFlow: PriorityFlow? = nil,
        loginItem: LoginItemSettings? = nil,
        shortcut: ShortcutSettings? = nil
    ) {
        self.store = store
        self.priorityFlow = priorityFlow ?? PriorityFlow(store: store)
        self.loginItem = loginItem ?? LoginItemSettings(service: InertLoginItemService())
        self.shortcut = shortcut ?? ShortcutSettings(service: InertHotkeyService())
        tab = store.value(for: Self.tabKey)
        let legacy = store.value(for: Self.legacyScopeKey)
        filter = store.value(for: Self.filterKey) ?? (legacy == .week ? .week : .today)
        noteScope = store.value(for: Self.noteScopeKey) ?? (legacy == .week ? .week : .day)
        isDoneOpen = store.value(for: Self.doneOpenKey)
    }

    var detailPriority: Priority? {
        guard let id = openPriorityID, let priority = store.priority(id: id) else { return nil }
        guard !priority.isDone || detailOpenedDone else { return nil }
        return priority
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

    func select(noteScope newScope: NoteScope) {
        guard newScope != noteScope else { return }
        noteScope = newScope
        persist { try store.setValue(newScope, for: Self.noteScopeKey) }
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
