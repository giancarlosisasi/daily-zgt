import AppKit
import Foundation
import KeyboardShortcuts
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct GlobalHotkeyServiceTests {
    @Test
    func theDefaultShortcutIsControlOptionCommandP() {
        let shortcut = CaptureShortcut.defaultShortcut
        #expect(shortcut == KeyboardShortcuts.Shortcut(.p, modifiers: [.control, .option, .command]))
        #expect(shortcut.description == "⌃⌥⌘P")
    }

    @Test
    func theRealNameHasTheDefaultShortcutAsItsInitialValue() {
        let name = CaptureShortcut.name("captureWindowNameCheck")
        defer { UserDefaults.standard.removeObject(forKey: "KeyboardShortcuts_captureWindowNameCheck") }
        #expect(name.initialShortcut == CaptureShortcut.defaultShortcut)
        #expect(name.rawValue == "captureWindowNameCheck")
        #expect(CaptureShortcut.rawValue == "captureWindow")
    }

    @Test
    func theDefaultIsStoredWhenNothingIsStored() {
        let hotkey = FakeHotkeyService()
        defer { hotkey.removeStoredValue() }
        #expect(hotkey.currentShortcut == CaptureShortcut.defaultShortcut)
    }

    @Test
    func aClearedShortcutStaysClearedWhenTheNameIsMadeAgain() {
        let hotkey = FakeHotkeyService()
        defer { hotkey.removeStoredValue() }
        #expect(hotkey.currentShortcut != nil)

        hotkey.clearShortcut()
        #expect(hotkey.currentShortcut == nil)

        let nextLaunch = CaptureShortcut.name(hotkey.rawValue)
        #expect(KeyboardShortcuts.getShortcut(for: nextLaunch) == nil)
    }

    @Test
    func aChangedShortcutStaysChangedWhenTheNameIsMadeAgain() {
        let hotkey = FakeHotkeyService()
        defer { hotkey.removeStoredValue() }
        let changed = KeyboardShortcuts.Shortcut(.k, modifiers: [.command, .option])
        KeyboardShortcuts.setShortcut(changed, for: hotkey.shortcutName)

        let nextLaunch = CaptureShortcut.name(hotkey.rawValue)
        #expect(KeyboardShortcuts.getShortcut(for: nextLaunch) == changed)
    }

    @Test
    func theTestHostUsesTheInertService() {
        #expect(AppDatabase.isTestHost)
        #expect(AppBoot.hotkeyService(isTestHost: true) is InertHotkeyService)
    }

    @Test
    func theRealServiceIsUsedOutsideATestHost() {
        let raw = "test-\(UUID().uuidString)"
        defer { UserDefaults.standard.removeObject(forKey: "KeyboardShortcuts_\(raw)") }
        let service = AppBoot.hotkeyService(isTestHost: false, name: CaptureShortcut.name(raw))
        #expect(service is SystemHotkeyService)
        #expect(service.shortcutName.rawValue == raw)
        #expect(service.currentShortcut == CaptureShortcut.defaultShortcut)
    }

    @Test
    func theInertServiceNeverCallsTheHandlerAndHasNoShortcut() {
        let service = InertHotkeyService()
        var calls = 0
        service.start { calls += 1 }
        #expect(calls == 0)
        #expect(service.currentShortcut == nil)
    }

    @Test
    func aBootInATestRunRegistersNoShortcut() {
        guard case let .ready(_, state, _, capture) = AppBoot.start() else {
            Issue.record("The boot must be ready in a test run.")
            return
        }
        #expect(state.shortcut.name.rawValue != CaptureShortcut.rawValue)
        #expect(!state.shortcut.isSet)
        #expect(!capture.isOpen)
    }

    @Test
    func theFakeServiceCallsTheHandlerOnFire() {
        let hotkey = FakeHotkeyService()
        defer { hotkey.removeStoredValue() }
        var calls = 0
        hotkey.start { calls += 1 }
        hotkey.fire()
        hotkey.fire()
        #expect(calls == 2)
    }
}

@Suite
@MainActor
struct ShortcutSettingsTests {
    @Test
    func readsTheStoredShortcutAtStart() {
        let hotkey = FakeHotkeyService()
        defer { hotkey.removeStoredValue() }
        let settings = ShortcutSettings(service: hotkey)
        #expect(settings.shortcut == CaptureShortcut.defaultShortcut)
        #expect(settings.isSet)
        #expect(settings.name == hotkey.shortcutName)
    }

    @Test
    func aClearedShortcutIsNotSet() {
        let hotkey = FakeHotkeyService()
        defer { hotkey.removeStoredValue() }
        hotkey.clearShortcut()
        let settings = ShortcutSettings(service: hotkey)
        #expect(settings.shortcut == nil)
        #expect(!settings.isSet)
    }

    @Test
    func theRecorderCallbackUpdatesTheState() {
        let hotkey = FakeHotkeyService()
        defer { hotkey.removeStoredValue() }
        let settings = ShortcutSettings(service: hotkey)
        settings.shortcutDidChange(nil)
        #expect(!settings.isSet)
        let changed = KeyboardShortcuts.Shortcut(.k, modifiers: [.command, .option])
        settings.shortcutDidChange(changed)
        #expect(settings.shortcut == changed)
    }

    @Test
    func refreshReadsTheStoreAgain() {
        let hotkey = FakeHotkeyService()
        defer { hotkey.removeStoredValue() }
        let settings = ShortcutSettings(service: hotkey)
        hotkey.clearShortcut()
        #expect(settings.isSet)
        settings.refresh()
        #expect(!settings.isSet)
    }

    @Test
    func openingTheSettingsReadsTheStoreAgain() throws {
        let hotkey = FakeHotkeyService()
        defer { hotkey.removeStoredValue() }
        let settings = ShortcutSettings(service: hotkey)
        let state = PanelState(store: try makeStore(), shortcut: settings)
        hotkey.clearShortcut()
        state.openSettings()
        #expect(!settings.isSet)
    }

    @Test
    func theRowCopyIsInSpanish() {
        #expect(SettingsCopy.shortcutTitle == "Atajo global")
        #expect(SettingsCopy.shortcutDetail == "Abre la ventana de captura desde cualquier app.")
        #expect(SettingsCopy.shortcutClearedDetail.hasPrefix("Sin atajo"))
    }
}
