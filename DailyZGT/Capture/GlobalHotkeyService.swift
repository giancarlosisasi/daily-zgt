import AppKit
import KeyboardShortcuts
import os

enum HotkeyLog {
    static let logger = Logger(subsystem: "com.giancarlosisasi.dailyzgt", category: "hotkey")
}

enum CaptureShortcut {
    static let rawValue = "captureWindow"
    static let defaultShortcut = KeyboardShortcuts.Shortcut(.p, modifiers: [.control, .option, .command])
    static let captureWindow = name(rawValue)

    static func name(_ rawValue: String) -> KeyboardShortcuts.Name {
        KeyboardShortcuts.Name(rawValue, initial: defaultShortcut)
    }
}

@MainActor
protocol GlobalHotkeyService: AnyObject {
    var shortcutName: KeyboardShortcuts.Name { get }
    var currentShortcut: KeyboardShortcuts.Shortcut? { get }
    func start(onTrigger: @escaping @MainActor () -> Void)
}

@MainActor
final class SystemHotkeyService: GlobalHotkeyService {
    let shortcutName: KeyboardShortcuts.Name

    init(name: KeyboardShortcuts.Name) {
        shortcutName = name
    }

    var currentShortcut: KeyboardShortcuts.Shortcut? {
        KeyboardShortcuts.getShortcut(for: shortcutName)
    }

    func start(onTrigger: @escaping @MainActor () -> Void) {
        KeyboardShortcuts.onKeyUp(for: shortcutName) {
            onTrigger()
        }
        if let shortcut = currentShortcut {
            HotkeyLog.logger.notice("Capture shortcut registered: \(shortcut.description, privacy: .public)")
        } else {
            HotkeyLog.logger.notice("Capture shortcut is cleared: no global shortcut")
        }
    }
}

@MainActor
final class InertHotkeyService: GlobalHotkeyService {
    let shortcutName = KeyboardShortcuts.Name("inertCaptureWindow")

    var currentShortcut: KeyboardShortcuts.Shortcut? {
        KeyboardShortcuts.getShortcut(for: shortcutName)
    }

    func start(onTrigger: @escaping @MainActor () -> Void) {}
}
