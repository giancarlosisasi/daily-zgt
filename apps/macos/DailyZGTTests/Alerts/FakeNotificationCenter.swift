import Foundation
@testable import DailyZGT

struct FakeCenterError: Error {}

enum FakePermissionAnswer {
    case allow
    case deny
    case noAnswer
    case fail
}

@MainActor
final class FakeNotificationCenter: NotificationCenterClient {
    var status: AlertAuthorization
    var answer = FakePermissionAnswer.allow
    var pending: [String: AlertRequest] = [:]
    var addError: (any Error)?

    private(set) var requestCount = 0
    private(set) var pendingReads = 0
    private(set) var added: [AlertRequest] = []
    private(set) var removedPending: [[String]] = []
    private(set) var removedDelivered: [[String]] = []
    private(set) var handler: (any AlertEventHandler)?

    init(status: AlertAuthorization = .authorized) {
        self.status = status
    }

    func authorization() async -> AlertAuthorization {
        status
    }

    func requestAuthorization() async throws -> Bool {
        requestCount += 1
        switch answer {
        case .allow:
            status = .authorized
            return true
        case .deny:
            status = .denied
            return false
        case .noAnswer:
            return false
        case .fail:
            status = .denied
            throw FakeCenterError()
        }
    }

    func add(_ request: AlertRequest) async throws {
        if let addError {
            throw addError
        }
        added.append(request)
        pending[request.id] = request
    }

    func pendingRequests() async -> [AlertRequest] {
        pendingReads += 1
        return pending.values.sorted { $0.id < $1.id }
    }

    func removePending(ids: [String]) async {
        removedPending.append(ids)
        for id in ids {
            pending[id] = nil
        }
    }

    func removeDelivered(ids: [String]) async {
        removedDelivered.append(ids)
    }

    func install(handler: any AlertEventHandler) {
        self.handler = handler
    }
}
