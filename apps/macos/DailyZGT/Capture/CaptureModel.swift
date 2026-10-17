import Observation

enum CaptureCopy {
    static let title = "Nueva prioridad"
    static let placeholder = "¿Qué es prioritario?"
    static let hint = "Enter agrega. Escape cierra."
    static let saveFailed = "No se pudo guardar la prioridad."
}

@Observable
@MainActor
final class CaptureModel {
    var draft = NewPriorityDraft()
    private(set) var limitMessage: String?
    private(set) var saveFailed = false
    private(set) var focusRequests = 0

    @ObservationIgnored private let store: AppStore

    init(store: AppStore) {
        self.store = store
    }

    var notice: String? {
        if let limitMessage { return limitMessage }
        return saveFailed ? CaptureCopy.saveFailed : nil
    }

    func reset() {
        draft = NewPriorityDraft()
        limitMessage = nil
        saveFailed = false
    }

    func requestFocus() {
        focusRequests += 1
    }

    @discardableResult
    func submit() -> Bool {
        guard draft.canAdd else { return false }
        if let block = store.todayAddBlock() {
            limitMessage = block
            return false
        }
        do {
            try store.addPriority(title: draft.trimmedTitle, level: .medium, list: .today, dueAt: nil)
        } catch {
            limitMessage = nil
            saveFailed = true
            return false
        }
        reset()
        return true
    }
}
