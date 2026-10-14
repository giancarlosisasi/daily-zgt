import Foundation

enum AlertAuthorization: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
}

struct AlertRequest: Equatable, Sendable {
    static let testID = "test-alert"

    var id: String
    var title: String
    var body: String
    var fireAt: Date
    var priorityID: Priority.ID?
}

enum AlertAction: Equatable, Sendable {
    case open
    case snooze
}

struct AlertResponse: Equatable, Sendable {
    var alertID: String
    var priorityID: Priority.ID?
    var action: AlertAction
}

@MainActor
protocol AlertEventHandler: AnyObject, Sendable {
    func alertWasPresented(id: String)
    func alertWasAnswered(_ response: AlertResponse) async
}

protocol NotificationCenterClient: Sendable {
    func authorization() async -> AlertAuthorization
    func requestAuthorization() async throws -> Bool
    func add(_ request: AlertRequest) async throws
    func pendingRequests() async -> [AlertRequest]
    func removePending(ids: [String]) async
    func removeDelivered(ids: [String]) async
    @MainActor func install(handler: any AlertEventHandler)
}

struct InertNotificationCenter: NotificationCenterClient {
    func authorization() async -> AlertAuthorization { .notDetermined }
    func requestAuthorization() async throws -> Bool { false }
    func add(_ request: AlertRequest) async throws {}
    func pendingRequests() async -> [AlertRequest] { [] }
    func removePending(ids: [String]) async {}
    func removeDelivered(ids: [String]) async {}
    @MainActor func install(handler: any AlertEventHandler) {}
}
