import AppKit
import Foundation
import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct SettingsRenderTests {
    let clock = TestClock("2026-10-12T10:24:00")

    private func openPanel(
        service: FakeLoginItemService,
        failRegister: Bool = false
    ) throws -> (AppStore, PanelState) {
        let store = try makeStore(clock)
        try store.addPriority(title: "Terminar el brief de Tailwind v4", level: .high, list: .today)
        let state = PanelState(store: store, loginItem: LoginItemSettings(service: service, events: NotificationCenter()))
        state.openSettings()
        if failRegister {
            state.loginItem.set(true)
        }
        return (store, state)
    }

    private func render(_ name: String, service: FakeLoginItemService, failRegister: Bool = false) throws {
        let (store, state) = try openPanel(service: service, failRegister: failRegister)
        let view = PanelView().environment(store).environment(state)
        let url = try Screenshot.writeHosted(view, named: name)
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func rendersTheSettingsWithTheToggleOff() throws {
        try render("settings-off", service: FakeLoginItemService(status: .notRegistered))
    }

    @Test
    func rendersTheSettingsWithTheToggleOn() throws {
        try render("settings-on", service: FakeLoginItemService(status: .enabled))
    }

    @Test
    func rendersTheSettingsWithTheApprovalLine() throws {
        try render("settings-approval", service: FakeLoginItemService(status: .requiresApproval))
    }

    @Test
    func rendersTheSettingsWithTheErrorLine() throws {
        let service = FakeLoginItemService(status: .notRegistered)
        service.registerError = FakeLoginItemError()
        try render("settings-error", service: service, failRegister: true)
    }

    @Test
    func rendersTheSettingsNotFound() throws {
        try render("settings-not-found", service: FakeLoginItemService(status: .notFound))
    }

    @Test
    func rendersTheFooterWithTheGear() throws {
        let footer = PanelFooter(summary: "2 de 5 hechas hoy", actions: {
            TestAlertButton {}
            SettingsButton {}
        })
        let url = try Screenshot.writeHosted(footer.panelChrome(), named: "footer-gear")
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func rendersTheFooterWithTheGearOpen() throws {
        let footer = PanelFooter(summary: "2 de 5 hechas hoy", actions: {
            TestAlertButton {}
            SettingsButton(isOpen: true) {}
        })
        let url = try Screenshot.writeHosted(footer.panelChrome(), named: "footer-gear-open")
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func rendersTheToggleInBothStates() throws {
        let toggles = HStack(spacing: Theme.Panel.spacing) {
            SettingsToggle(title: "Apagado", isOn: false) { _ in }
            SettingsToggle(title: "Encendido", isOn: true) { _ in }
        }
        let url = try Screenshot.writeHosted(toggles.panelChrome(), named: "settings-toggles")
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func theApprovalLineAddsHeight() throws {
        let plain = try openPanel(service: FakeLoginItemService(status: .notRegistered))
        let approval = try openPanel(service: FakeLoginItemService(status: .requiresApproval))
        func height(_ panel: (AppStore, PanelState)) -> CGFloat {
            NSHostingView(rootView: PanelView().environment(panel.0).environment(panel.1)).fittingSize.height
        }
        #expect(height(approval) > height(plain))
    }
}
