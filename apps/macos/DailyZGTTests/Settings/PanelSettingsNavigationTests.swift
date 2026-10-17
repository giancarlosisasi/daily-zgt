import Foundation
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct PanelSettingsNavigationTests {
    let clock = TestClock("2026-10-12T10:24:00")
    let service = FakeLoginItemService(status: .notRegistered)

    private func makeState(_ store: AppStore) -> PanelState {
        PanelState(store: store, loginItem: LoginItemSettings(service: service, events: NotificationCenter()))
    }

    @Test
    func theSettingsAreClosedAtStart() throws {
        let state = makeState(try makeStore(clock))
        #expect(!state.isSettingsOpen)
    }

    @Test
    func openAndBackToggleTheSettings() throws {
        let state = makeState(try makeStore(clock))
        state.openSettings()
        #expect(state.isSettingsOpen)
        state.closeSettings()
        #expect(!state.isSettingsOpen)
    }

    @Test
    func theGearOpensAndClosesTheSettings() throws {
        let state = makeState(try makeStore(clock))
        state.toggleSettings()
        #expect(state.isSettingsOpen)
        state.toggleSettings()
        #expect(!state.isSettingsOpen)
    }

    @Test
    func openingTheSettingsClosesTheDetail() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "Mandar el reporte", list: .today)
        let state = makeState(store)
        state.openDetail(priority.id)
        #expect(state.detailPriority != nil)

        state.openSettings()

        #expect(state.isSettingsOpen)
        #expect(state.detailPriority == nil)
        #expect(state.openPriorityID == nil)
    }

    @Test
    func openingTheDetailClosesTheSettings() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "Mandar el reporte", list: .today)
        let state = makeState(store)
        state.openSettings()

        state.openDetail(priority.id)

        #expect(!state.isSettingsOpen)
        #expect(state.detailPriority?.id == priority.id)
    }

    @Test
    func theDetailAndTheSettingsNeverShowTogether() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "Mandar el reporte", list: .today)
        let state = makeState(store)
        let steps: [@MainActor () -> Void] = [
            { state.openDetail(priority.id) },
            { state.openSettings() },
            { state.openDetail(priority.id) },
            { state.toggleSettings() },
            { state.showInList(priority.id) },
            { state.openSettings() },
            { state.select(tab: .notes) },
            { state.openSettings() },
            { state.closeSettings() },
        ]
        for step in steps {
            step()
            #expect(!(state.isSettingsOpen && state.detailPriority != nil))
        }
    }

    @Test
    func anAlertThatShowsAPriorityClosesTheSettings() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "Mandar el reporte", list: .week)
        let state = makeState(store)
        state.openSettings()

        state.showInList(priority.id)

        #expect(!state.isSettingsOpen)
        #expect(state.tab == .priorities)
        #expect(state.scope == .week)
    }

    @Test
    func aTabChangeClosesTheSettings() throws {
        let state = makeState(try makeStore(clock))
        state.openSettings()
        state.select(tab: .notes)
        #expect(!state.isSettingsOpen)
        #expect(state.tab == .notes)
    }

    @Test
    func openingTheSettingsReadsTheLoginItemStatusAgain() throws {
        let state = makeState(try makeStore(clock))
        #expect(!state.loginItem.isOn)
        service.status = .enabled
        #expect(!state.loginItem.isOn)

        state.openSettings()

        #expect(state.loginItem.isOn)
    }

    @Test
    func theSettingsStateIsNotKeptInTheDatabase() throws {
        let store = try makeStore(clock)
        let state = makeState(store)
        state.openSettings()
        state.loginItem.set(true)
        let keys = try values("SELECT key FROM app_state", in: store.database, as: String.self)
        #expect(keys.isEmpty)
    }

    @Test
    func aStateWithNoLoginItemUsesTheInertService() throws {
        let state = PanelState(store: try makeStore(clock))
        state.openSettings()
        state.loginItem.set(true)
        #expect(!state.loginItem.isOn)
    }
}
