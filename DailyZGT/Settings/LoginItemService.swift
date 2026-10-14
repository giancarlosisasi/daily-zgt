import ServiceManagement

enum LoginItemStatus: Equatable, CaseIterable, Sendable {
    case enabled
    case notRegistered
    case requiresApproval
    case notFound
}

@MainActor
protocol LoginItemService {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() throws
}

struct SystemLoginItemService: LoginItemService {
    var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .notRegistered: .notRegistered
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        @unknown default: .notFound
        }
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

struct InertLoginItemService: LoginItemService {
    var status: LoginItemStatus { .notRegistered }
    func register() throws {}
    func unregister() throws {}
}
