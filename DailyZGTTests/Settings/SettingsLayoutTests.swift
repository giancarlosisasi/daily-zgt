import AppKit
import Foundation
import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct SettingsLayoutTests {
    let clock = TestClock("2026-10-12T10:24:00")
    let contentWidth = Theme.Panel.width - 2 * Theme.Panel.padding

    private func height(_ view: some View) -> CGFloat {
        NSHostingView(rootView: view.frame(width: contentWidth).environment(\.colorScheme, .dark)).fittingSize.height
    }

    private func rowHeight(title: String) -> CGFloat {
        height(SettingsRow(title: title, detail: "Detalle") { SettingsToggle(title: title, isOn: false) { _ in } })
    }

    private var titleLineHeight: CGFloat {
        NSLayoutManager().defaultLineHeight(for: Theme.Font.rowTitle)
    }

    @Test
    func eachTitleShowsAllItsLinesAndTheRowGrowsByTheExtraLines() {
        let oneLine = rowHeight(title: "Atajo")
        let titles: [(String, CGFloat)] = [
            (SettingsCopy.loginTitle, 0),
            (SettingsCopy.todayLimitTitle, 0),
            (SettingsCopy.menuBarTitleTitle, 1),
            (SettingsCopy.shortcutTitle, 0),
        ]
        for (title, extraLines) in titles {
            let growth = rowHeight(title: title) - oneLine

            #expect(abs(growth - extraLines * titleLineHeight) < 1, "\(title)")
        }
    }

    @Test
    func theSettingsHeightIsTheHeaderPlusEachRowPlusTheGaps() throws {
        let store = try makeStore(clock)
        let hotkey = FakeHotkeyService()
        defer { hotkey.removeStoredValue() }
        let loginItem = LoginItemSettings(service: FakeLoginItemService(status: .notRegistered), events: NotificationCenter())
        let shortcut = ShortcutSettings(service: hotkey)
        let state = PanelState(store: store, loginItem: loginItem, shortcut: shortcut)

        let whole = height(SettingsView().environment(store).environment(state))
        let rows = height(LoginItemRow(model: loginItem))
            + height(TodayLimitRow(isOn: false) { _ in })
            + height(MenuBarTitleRow(isOn: true) { _ in })
            + height(ShortcutRow(model: shortcut))
        let header = height(SettingsHeader(onBack: {}))
        let gaps = 3 * Theme.Settings.spacing + Theme.Detail.spacing

        #expect(abs(whole - (header + rows + gaps)) < 1)
    }
}
