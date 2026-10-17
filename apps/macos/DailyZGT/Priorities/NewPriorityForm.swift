import Foundation

struct NewPriorityDraft: Equatable {
    var title = ""
    var level: PriorityLevel = .medium
    var dueAt: Date?

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canAdd: Bool {
        !trimmedTitle.isEmpty
    }

    var showsAlertHint: Bool {
        dueAt != nil
    }

    static func defaultDue(after now: Date, calendar: Calendar = .current) -> Date {
        let startOfHour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        return calendar.date(byAdding: .hour, value: 1, to: startOfHour) ?? now
    }
}

struct NewPriorityForm: Equatable {
    private(set) var isOpen = false
    private(set) var isBlockedByLimit = false
    var draft = NewPriorityDraft()

    mutating func open() {
        isOpen = true
    }

    mutating func close() {
        isOpen = false
    }

    mutating func cancel() {
        isOpen = false
        isBlockedByLimit = false
        draft = NewPriorityDraft()
    }

    @MainActor
    @discardableResult
    mutating func submit(to store: AppStore, list: PriorityList) throws -> Priority? {
        guard draft.canAdd else { return nil }
        if list == .today, !store.canAddToToday() {
            isBlockedByLimit = true
            return nil
        }
        isBlockedByLimit = false
        let added = try store.addPriority(
            title: draft.trimmedTitle,
            level: draft.level,
            list: list,
            dueAt: draft.dueAt
        )
        cancel()
        return added
    }
}
