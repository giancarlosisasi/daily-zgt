import KeyboardShortcuts
import Observation

@Observable
@MainActor
final class ShortcutSettings {
    private(set) var shortcut: KeyboardShortcuts.Shortcut?

    @ObservationIgnored let name: KeyboardShortcuts.Name
    @ObservationIgnored private let service: any GlobalHotkeyService

    init(service: any GlobalHotkeyService) {
        self.service = service
        name = service.shortcutName
        shortcut = service.currentShortcut
    }

    var isSet: Bool {
        shortcut != nil
    }

    func refresh() {
        shortcut = service.currentShortcut
    }

    func shortcutDidChange(_ changed: KeyboardShortcuts.Shortcut?) {
        shortcut = changed
    }
}
