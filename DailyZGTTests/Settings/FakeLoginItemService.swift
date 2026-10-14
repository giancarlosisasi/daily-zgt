import Foundation
@testable import DailyZGT

struct FakeLoginItemError: Error {}

@MainActor
final class FakeLoginItemService: LoginItemService {
    var status: LoginItemStatus
    var statusAfterRegister = LoginItemStatus.enabled
    var registerError: (any Error)?
    var unregisterError: (any Error)?

    private(set) var registerCalls = 0
    private(set) var unregisterCalls = 0

    init(status: LoginItemStatus = .notRegistered) {
        self.status = status
    }

    func register() throws {
        registerCalls += 1
        if let registerError {
            throw registerError
        }
        status = statusAfterRegister
    }

    func unregister() throws {
        unregisterCalls += 1
        if let unregisterError {
            throw unregisterError
        }
        status = .notRegistered
    }
}
