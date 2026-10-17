import AppKit
import SwiftUI

@main
struct DailyZGTApp: App {
    private let boot: AppBoot

    init() {
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        TeclaFonts.register()
        TeclaFonts.logRegistration()
        boot = AppBoot.start()
    }

    var body: some Scene {
        MenuBarExtra {
            AppRootView(boot: boot)
        } label: {
            MenuBarLabelHost(boot: boot)
        }
        .menuBarExtraStyle(.window)
    }
}
