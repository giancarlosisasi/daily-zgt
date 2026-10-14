import Foundation
import KeyboardShortcuts
@testable import DailyZGT

@MainActor
final class FakeHotkeyService: GlobalHotkeyService {
    let rawValue = "test-\(UUID().uuidString)"
    let shortcutName: KeyboardShortcuts.Name
    private(set) var startCalls = 0
    private var handler: (@MainActor () -> Void)?

    init() {
        shortcutName = CaptureShortcut.name(rawValue)
    }

    var currentShortcut: KeyboardShortcuts.Shortcut? {
        KeyboardShortcuts.getShortcut(for: shortcutName)
    }

    func start(onTrigger: @escaping @MainActor () -> Void) {
        startCalls += 1
        handler = onTrigger
    }

    func fire() {
        handler?()
    }

    func clearShortcut() {
        KeyboardShortcuts.setShortcut(nil, for: shortcutName)
    }

    func removeStoredValue() {
        UserDefaults.standard.removeObject(forKey: "KeyboardShortcuts_\(rawValue)")
    }
}

@MainActor
final class FakeCaptureWindow: CaptureWindow {
    private(set) var showCalls = 0
    private(set) var hideCalls = 0

    func show() {
        showCalls += 1
    }

    func hide() {
        hideCalls += 1
    }
}

@MainActor
final class CaptureWindowRecorder {
    private(set) var windows: [FakeCaptureWindow] = []

    var factory: @MainActor (CaptureController) -> any CaptureWindow {
        { [self] _ in
            let window = FakeCaptureWindow()
            windows.append(window)
            return window
        }
    }
}
