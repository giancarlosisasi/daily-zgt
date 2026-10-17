import Foundation

enum ListMoveResult: Equatable {
    case moved
    case blocked(String)
}

@MainActor
struct PriorityDetailActions {
    let store: AppStore
    let id: Priority.ID

    func commitTitle(_ draft: String) throws -> String {
        guard let current = store.priority(id: id)?.title else { return draft }
        guard let title = TitleEdit.titleToSave(draft: draft, current: current) else { return current }
        try store.editPriority(id) { $0.title = title }
        return title
    }

    func setLevel(_ level: PriorityLevel) throws {
        try store.editPriority(id) { $0.level = level }
    }

    func setDue(_ due: Date?) throws {
        try store.editPriority(id) { $0.dueAt = due }
    }

    @discardableResult
    func setList(_ list: PriorityList) throws -> ListMoveResult {
        if list == .today, store.priority(id: id)?.list == .week, let block = store.todayAddBlock() {
            return .blocked(block)
        }
        try store.movePriority(id, to: list)
        return .moved
    }

    func setRepeat(_ rule: RepeatRule) throws {
        try store.editPriority(id) { $0.repeatRule = rule }
    }
}
