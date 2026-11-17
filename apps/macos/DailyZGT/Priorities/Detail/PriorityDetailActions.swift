import Foundation

enum DueChangeResult: Equatable {
    case saved
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

    @discardableResult
    func setDue(_ due: Date?) throws -> DueChangeResult {
        if let block = store.dueChangeBlock(for: id, to: due) {
            return .blocked(block)
        }
        try store.editPriority(id) { $0.dueAt = due }
        return .saved
    }

    func setRepeat(_ rule: RepeatRule) throws {
        try store.editPriority(id) { $0.repeatRule = rule }
    }
}
