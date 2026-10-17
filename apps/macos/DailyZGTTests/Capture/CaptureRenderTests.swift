import AppKit
import Foundation
import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct CaptureRenderTests {
    let clock = TestClock("2026-10-12T10:24:00")

    private func write(_ view: some View, named name: String) throws {
        let url = try Screenshot.writeHosted(view, named: name)
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    private func captureView(_ model: CaptureModel, focused: Bool = true) -> some View {
        CaptureView(model: model, reveal: CaptureReveal(isRevealed: true), showsTitleFocus: focused)
            .padding(24)
            .background(Color(TeclaTokens.Colors.ground))
    }

    @Test
    func rendersTheCaptureWindowEmpty() throws {
        let model = CaptureModel(store: try makeStore(clock))
        try write(captureView(model), named: "capture-empty")
    }

    @Test
    func rendersTheCaptureWindowWithText() throws {
        let model = CaptureModel(store: try makeStore(clock))
        model.draft.title = "Terminar el brief de Tailwind v4"
        try write(captureView(model), named: "capture-text")
    }

    @Test
    func rendersTheCaptureWindowWithTheLimitLine() throws {
        let store = try makeStore(clock)
        PanelState(store: store).setTodayLimit(true)
        for index in 0..<TodayLimit.maxOpen {
            try store.addPriority(title: "Open \(index)", list: .today)
        }
        let model = CaptureModel(store: store)
        model.draft.title = "Una más"
        model.submit()
        #expect(model.notice == TodayLimit.message)
        try write(captureView(model), named: "capture-limit")
    }

    @Test
    func rendersTheCaptureWindowWithTheSaveLine() throws {
        let store = try makeStore(clock)
        try execute("DROP TABLE priority_event", in: store.database)
        let model = CaptureModel(store: store)
        model.draft.title = "Pagar la luz"
        model.submit()
        #expect(model.notice == CaptureCopy.saveFailed)
        try write(captureView(model), named: "capture-save-failed")
    }

    @Test
    func theLimitLineAddsHeight() throws {
        let store = try makeStore(clock)
        PanelState(store: store).setTodayLimit(true)
        for index in 0..<TodayLimit.maxOpen {
            try store.addPriority(title: "Open \(index)", list: .today)
        }
        let plain = CaptureModel(store: store)
        let blocked = CaptureModel(store: store)
        blocked.draft.title = "Una más"
        blocked.submit()
        func height(_ model: CaptureModel) -> CGFloat {
            NSHostingView(rootView: CaptureView(model: model, reveal: CaptureReveal(isRevealed: true))).fittingSize.height
        }
        #expect(height(blocked) > height(plain))
    }

    @Test
    func theWindowIsAsWideAsThePanel() throws {
        let model = CaptureModel(store: try makeStore(clock))
        let size = NSHostingView(rootView: CaptureView(model: model, reveal: CaptureReveal(isRevealed: true))).fittingSize
        #expect(size.width == Theme.Panel.width)
    }

    private func settingsPanel(hotkey: FakeHotkeyService) throws -> some View {
        let store = try makeStore(clock)
        try store.addPriority(title: "Terminar el brief de Tailwind v4", level: .high, list: .today)
        let state = PanelState(
            store: store,
            loginItem: LoginItemSettings(service: FakeLoginItemService(status: .notRegistered), events: NotificationCenter()),
            shortcut: ShortcutSettings(service: hotkey)
        )
        state.openSettings()
        return PanelView().environment(store).environment(state)
    }

    @Test
    func rendersTheSettingsWithTheShortcutSet() throws {
        let hotkey = FakeHotkeyService()
        defer { hotkey.removeStoredValue() }
        try write(settingsPanel(hotkey: hotkey), named: "settings-shortcut")
    }

    @Test
    func rendersTheSettingsWithTheShortcutCleared() throws {
        let hotkey = FakeHotkeyService()
        defer { hotkey.removeStoredValue() }
        hotkey.clearShortcut()
        try write(settingsPanel(hotkey: hotkey), named: "settings-shortcut-cleared")
    }
}
