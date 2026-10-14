import AppKit
import Foundation
import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct LoginItemSettingsTests {
    let events = NotificationCenter()

    private func model(_ service: FakeLoginItemService, opened: (@MainActor () -> Void)? = nil) -> LoginItemSettings {
        LoginItemSettings(service: service, events: events, openSystemSettings: opened ?? {})
    }

    @Test(arguments: [
        (LoginItemStatus.enabled, true, false),
        (LoginItemStatus.notRegistered, false, false),
        (LoginItemStatus.requiresApproval, true, true),
        (LoginItemStatus.notFound, false, false),
    ])
    func eachStatusSetsTheToggleAndTheApprovalLine(status: LoginItemStatus, isOn: Bool, needsApproval: Bool) {
        let settings = model(FakeLoginItemService(status: status))
        #expect(settings.status == status)
        #expect(settings.isOn == isOn)
        #expect(settings.needsApproval == needsApproval)
        #expect(!settings.registerFailed)
    }

    @Test
    func theToggleOnRegistersTheApp() {
        let service = FakeLoginItemService(status: .notRegistered)
        let settings = model(service)
        settings.set(true)
        #expect(service.registerCalls == 1)
        #expect(service.unregisterCalls == 0)
        #expect(settings.status == .enabled)
        #expect(settings.isOn)
    }

    @Test
    func theToggleOffUnregistersTheApp() {
        let service = FakeLoginItemService(status: .enabled)
        let settings = model(service)
        settings.set(false)
        #expect(service.unregisterCalls == 1)
        #expect(service.registerCalls == 0)
        #expect(settings.status == .notRegistered)
        #expect(!settings.isOn)
    }

    @Test
    func aToggleToTheStateThatIsAlreadySetCallsNothing() {
        let service = FakeLoginItemService(status: .enabled)
        let settings = model(service)
        settings.set(true)
        #expect(service.registerCalls == 0)
        #expect(service.unregisterCalls == 0)
    }

    @Test
    func aFailedRegisterKeepsTheToggleOffAndShowsTheError() {
        let service = FakeLoginItemService(status: .notRegistered)
        service.registerError = FakeLoginItemError()
        let settings = model(service)
        settings.set(true)
        #expect(service.registerCalls == 1)
        #expect(settings.registerFailed)
        #expect(!settings.isOn)
        #expect(settings.status == .notRegistered)
    }

    @Test
    func aFailedUnregisterKeepsTheToggleOnAndShowsTheError() {
        let service = FakeLoginItemService(status: .enabled)
        service.unregisterError = FakeLoginItemError()
        let settings = model(service)
        settings.set(false)
        #expect(settings.registerFailed)
        #expect(settings.isOn)
    }

    @Test
    func aLaterSuccessClearsTheError() {
        let service = FakeLoginItemService(status: .notRegistered)
        service.registerError = FakeLoginItemError()
        let settings = model(service)
        settings.set(true)
        service.registerError = nil
        settings.set(true)
        #expect(!settings.registerFailed)
        #expect(settings.isOn)
    }

    @Test
    func aRegisterThatNeedsApprovalShowsTheApprovalLine() {
        let service = FakeLoginItemService(status: .notRegistered)
        service.statusAfterRegister = .requiresApproval
        let settings = model(service)
        settings.set(true)
        #expect(settings.needsApproval)
        #expect(settings.isOn)
        #expect(!settings.registerFailed)
    }

    @Test
    func theToggleOffWhileApprovalIsMissingUnregisters() {
        let service = FakeLoginItemService(status: .requiresApproval)
        let settings = model(service)
        settings.set(false)
        #expect(service.unregisterCalls == 1)
        #expect(!settings.needsApproval)
        #expect(!settings.isOn)
    }

    @Test
    func theSystemCanChangeTheStatusAndARefreshShowsIt() {
        let service = FakeLoginItemService(status: .enabled)
        let settings = model(service)
        service.status = .notRegistered
        #expect(settings.isOn)
        settings.refresh()
        #expect(!settings.isOn)
    }

    @Test
    func aToggleReadsTheSystemBeforeItActs() {
        let service = FakeLoginItemService(status: .notRegistered)
        let settings = model(service)
        service.status = .enabled
        settings.set(true)
        #expect(service.registerCalls == 0)
        #expect(settings.isOn)
    }

    @Test
    func theAppBecomingActiveReadsTheStatusAgain() {
        let service = FakeLoginItemService(status: .notRegistered)
        let settings = model(service)
        settings.start()
        service.status = .requiresApproval
        #expect(!settings.isOn)
        events.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        #expect(settings.needsApproval)
    }

    @Test
    func theAppBecomingActiveKeepsTheError() {
        let service = FakeLoginItemService(status: .notRegistered)
        service.registerError = FakeLoginItemError()
        let settings = model(service)
        settings.start()
        settings.set(true)
        events.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        #expect(settings.registerFailed)
    }

    @Test
    func openingTheSettingsReadsTheStatusAndClearsTheError() {
        let service = FakeLoginItemService(status: .notRegistered)
        service.registerError = FakeLoginItemError()
        let settings = model(service)
        settings.set(true)
        service.status = .enabled
        settings.settingsDidOpen()
        #expect(settings.isOn)
        #expect(!settings.registerFailed)
    }

    @Test
    func theApprovalLinkOpensTheLoginItemsPane() {
        var opened = 0
        let settings = model(FakeLoginItemService(status: .requiresApproval), opened: { opened += 1 })
        settings.openLoginItems()
        #expect(opened == 1)
    }

    @Test
    func theLoginItemsUrlIsThePaneOfMacOS13AndLater() {
        #expect(LoginItemsSettings.url.absoluteString == "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
        var seen: [URL] = []
        let result = LoginItemsSettings.open { url in
            seen.append(url)
            return true
        }
        #expect(result)
        #expect(seen == [LoginItemsSettings.url])
    }

    @Test
    func theTestHostUsesTheInertService() {
        #expect(AppBoot.loginItemService(isTestHost: true) is InertLoginItemService)
        #expect(AppBoot.loginItemService(isTestHost: false) is SystemLoginItemService)
        #expect(AppDatabase.isTestHost)
        if case let .ready(_, state, _, _) = AppBoot.start() {
            #expect(state.loginItem.status == .notRegistered)
        } else {
            Issue.record("The boot must be ready in a test run.")
        }
    }

    @Test
    func theInertServiceDoesNothing() throws {
        let service = InertLoginItemService()
        try service.register()
        try service.unregister()
        #expect(service.status == .notRegistered)
    }
}

@Suite
@MainActor
struct SwitchGeometryTests {
    @Test
    func theKnobTravelsFromTheStartToTheEndOfTheTrack() {
        #expect(SwitchGeometry.knobOffset(isOn: false) == 0)
        #expect(SwitchGeometry.knobOffset(isOn: true) == Theme.Switch.travel)
        #expect(Theme.Switch.travel == 22)
    }

    @Test
    func theTrackFillsWithTheTeclaFillColor() {
        #expect(SwitchGeometry.trackColor(isOn: true) == Color(TeclaTokens.Colors.fill))
        #expect(SwitchGeometry.trackColor(isOn: false) == Color(TeclaTokens.Colors.surface2))
    }

    @Test
    func theToggleHasNoAnimationWithReduceMotion() {
        #expect(MotionPolicy(reduceMotion: true).animation(.slide) == nil)
        #expect(MotionPolicy(reduceMotion: false).animation(.slide) != nil)
    }

    @Test
    func theKnobStaysStillWithReduceMotionAndShowsTheTint() {
        let pressed = KeyPress(isPressed: true, reduceMotion: true)
        #expect(pressed.offset == 0)
        #expect(pressed.showsPressedTint)
        #expect(KeyPress(isPressed: true, reduceMotion: false).offset == Theme.Key.travel)
    }
}
