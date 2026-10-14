import Observation

enum PanelTab: String, Codable, CaseIterable, Sendable {
    case priorities
    case notes
}

extension PriorityList {
    var noteScope: NoteScope {
        switch self {
        case .today: .day
        case .week: .week
        }
    }
}

@Observable
@MainActor
final class PanelState {
    static let tabKey = AppStateKey(name: "open_tab", defaultValue: PanelTab.priorities)
    static let scopeKey = AppStateKey(name: "open_scope", defaultValue: PriorityList.today)
    static let doneOpenKey = AppStateKey(name: "done_open", defaultValue: false)

    private(set) var tab: PanelTab
    private(set) var scope: PriorityList
    private(set) var isDoneOpen: Bool
    private(set) var saveError: (any Error)?
    private(set) var openPriorityID: Priority.ID?
    private(set) var isSettingsOpen = false
    private(set) var isHistoryOpen = false

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
        scope = store.value(for: Self.scopeKey)
        isDoneOpen = store.value(for: Self.doneOpenKey)
    }

    var detailPriority: Priority? {
        guard let id = openPriorityID, let priority = store.priority(id: id), !priority.isDone else { return nil }
        return priority
    }

    var page: PanelPage {
        if isSettingsOpen { return .settings }
        if isHistoryOpen { return .history }
        return .browse
    }

    func openDetail(_ id: Priority.ID) {
        guard let priority = store.priority(id: id), !priority.isDone else { return }
        priorityFlow.cancelConfirmation()
        closeSettings()
        closeHistory()
        select(tab: .priorities)
        select(scope: priority.list)
        openPriorityID = id
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
        select(scope: priority?.list ?? .today)
        if let priority {
            priorityFlow.flash(priority.id)
        }
    }

    func closeDetail() {
        guard openPriorityID != nil else { return }
        openPriorityID = nil
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

    func select(scope newScope: PriorityList) {
        guard newScope != scope else { return }
        closeHistory()
        scope = newScope
        persist { try store.setValue(newScope, for: Self.scopeKey) }
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
