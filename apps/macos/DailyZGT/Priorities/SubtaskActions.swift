import Foundation

enum SubtaskTitle {
    static func cleaned(_ draft: String) -> String? {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }
}

@MainActor
struct SubtaskActions {
    let store: AppStore
    let priorityID: Priority.ID

    @discardableResult
    func add(_ draft: String) throws -> Subtask? {
        guard let title = SubtaskTitle.cleaned(draft) else { return nil }
        return try store.addSubtask(to: priorityID, title: title)
    }

    func toggle(_ id: Subtask.ID) throws {
        try store.toggleSubtask(id)
    }
}
