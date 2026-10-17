import KeyboardShortcuts
import SwiftUI

enum AppBoot {
    case ready(AppStore, PanelState, AlertCoordinator, CaptureController)
    case failed

    @MainActor
    static func loginItemService(isTestHost: Bool) -> any LoginItemService {
        isTestHost ? InertLoginItemService() : SystemLoginItemService()
    }

    @MainActor
    static func hotkeyService(
        isTestHost: Bool,
        name: @autoclosure () -> KeyboardShortcuts.Name = CaptureShortcut.captureWindow
    ) -> any GlobalHotkeyService {
        isTestHost ? InertHotkeyService() : SystemHotkeyService(name: name())
    }

    @MainActor
    static func start() -> AppBoot {
        do {
            let store = AppStore(database: try AppDatabase.forApp())
            let center: any NotificationCenterClient = AppDatabase.isTestHost
                ? InertNotificationCenter()
                : SystemNotificationCenter()
            let loginItem = LoginItemSettings(service: loginItemService(isTestHost: AppDatabase.isTestHost))
            let hotkey = hotkeyService(isTestHost: AppDatabase.isTestHost)
            let state = PanelState(store: store, loginItem: loginItem, shortcut: ShortcutSettings(service: hotkey))
            let capture = CaptureController(store: store)
            loginItem.start()
            let repeats = RepeatCoordinator(store: store)
            let alerts = AlertCoordinator(
                store: store,
                center: center,
                onOpen: { id in
                    state.showInList(id)
                    MenuBarPanel.open()
                },
                onDayMayHaveChanged: { repeats.run() }
            )
            repeats.start()
            alerts.start()
            capture.attach(to: hotkey)
            return .ready(store, state, alerts, capture)
        } catch {
            return .failed
        }
    }
}

struct AppRootView: View {
    let boot: AppBoot

    var body: some View {
        switch boot {
        case let .ready(store, state, alerts, _):
            PanelView()
                .panelPop()
                .environment(store)
                .environment(state)
                .environment(alerts)
        case .failed:
            DatabaseErrorView()
        }
    }
}

struct DatabaseErrorView: View {
    var body: some View {
        VStack(spacing: Theme.Panel.spacing) {
            Text("No se pudo abrir la base de datos.")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Text.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Theme.EmptyList.verticalPadding)
                .padding(.horizontal, Theme.EmptyList.horizontalPadding)
            PanelFooter(summary: "")
        }
        .panelChrome()
    }
}
