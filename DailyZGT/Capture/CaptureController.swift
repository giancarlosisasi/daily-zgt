import Observation

@MainActor
protocol CaptureWindow: AnyObject {
    func show()
    func hide()
}

@Observable
@MainActor
final class CaptureController {
    let model: CaptureModel
    private(set) var isOpen = false

    @ObservationIgnored private var window: (any CaptureWindow)?
    @ObservationIgnored private let makeWindow: @MainActor (CaptureController) -> any CaptureWindow

    init(
        store: AppStore,
        makeWindow: @escaping @MainActor (CaptureController) -> any CaptureWindow = { CapturePanelWindow(controller: $0) }
    ) {
        model = CaptureModel(store: store)
        self.makeWindow = makeWindow
    }

    func attach(to service: any GlobalHotkeyService) {
        service.start { [weak self] in
            self?.toggle()
        }
    }

    func toggle() {
        if isOpen {
            close()
        } else {
            open()
        }
    }

    func open() {
        guard !isOpen else { return }
        model.reset()
        let window = window ?? makeWindow(self)
        self.window = window
        isOpen = true
        window.show()
    }

    func close() {
        guard isOpen else { return }
        isOpen = false
        window?.hide()
    }

    func submit() {
        if model.submit() {
            close()
        }
    }

    func cancel() {
        close()
    }
}
