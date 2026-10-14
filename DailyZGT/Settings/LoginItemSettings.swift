import AppKit
import Observation
import os

enum LoginItemLog {
    static let logger = Logger(subsystem: "com.giancarlosisasi.dailyzgt", category: "login-item")
}

enum LoginItemsSettings {
    static let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!

    @MainActor
    @discardableResult
    static func open(using opener: (URL) -> Bool = { NSWorkspace.shared.open($0) }) -> Bool {
        opener(url)
    }
}

@Observable
@MainActor
final class LoginItemSettings {
    private(set) var status: LoginItemStatus
    private(set) var registerFailed = false

    @ObservationIgnored private let service: any LoginItemService
    @ObservationIgnored private let events: NotificationCenter
    @ObservationIgnored private let openSystemSettings: @MainActor () -> Void

    init(
        service: any LoginItemService,
        events: NotificationCenter = .default,
        openSystemSettings: @escaping @MainActor () -> Void = { LoginItemsSettings.open() }
    ) {
        self.service = service
        self.events = events
        self.openSystemSettings = openSystemSettings
        status = service.status
    }

    var isOn: Bool {
        status == .enabled || status == .requiresApproval
    }

    var needsApproval: Bool {
        status == .requiresApproval
    }

    func start() {
        _ = events.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    func refresh() {
        status = service.status
    }

    func settingsDidOpen() {
        registerFailed = false
        refresh()
    }

    func set(_ wantsOn: Bool) {
        refresh()
        guard wantsOn != isOn else { return }
        do {
            if wantsOn {
                try service.register()
            } else {
                try service.unregister()
            }
            registerFailed = false
        } catch {
            registerFailed = true
            LoginItemLog.logger.error("Login item change failed: \(String(describing: error), privacy: .public)")
        }
        refresh()
    }

    func openLoginItems() {
        openSystemSettings()
    }
}
