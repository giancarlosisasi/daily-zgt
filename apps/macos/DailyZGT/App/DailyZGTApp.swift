import AppKit
import SwiftUI

@main
struct DailyZGTApp: App {
    static func insertsMenuBarItem(isTestHost: Bool) -> Bool {
        !isTestHost
    }

    private let boot: AppBoot

    init() {
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        TeclaFonts.register()
        TeclaFonts.logRegistration()
        boot = AppBoot.start()
    }

    var body: some Scene {
        MenuBarExtra(isInserted: .constant(Self.insertsMenuBarItem(isTestHost: AppDatabase.isTestHost))) {
            AppRootView(boot: boot)
        } label: {
            MenuBarLabelHost(boot: boot)
        }
        .menuBarExtraStyle(.window)
    }
}
