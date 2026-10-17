import Foundation
import UserNotifications

final class SystemNotificationCenter: NotificationCenterClient {
    static let categoryID = "priority-alert"
    static let openActionID = "open"
    static let snoozeActionID = "snooze"
    static let alertKey = "alert_id"
    static let priorityKey = "priority_id"

    private let delegate = AlertNotificationDelegate()

    func authorization() async -> AlertAuthorization {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        default: .authorized
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func add(_ request: AlertRequest) async throws {
        try await UNUserNotificationCenter.current().add(Self.makeRequest(request))
    }

    func pendingRequests() async -> [AlertRequest] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().compactMap { Self.alertRequest(from: $0) }
    }

    func removePending(ids: [String]) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    func removeDelivered(ids: [String]) async {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
    }

    @MainActor
    func install(handler: any AlertEventHandler) {
        delegate.handler = handler
        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([Self.makeCategory()])
        center.delegate = delegate
    }

    static func makeCategory() -> UNNotificationCategory {
        UNNotificationCategory(
            identifier: categoryID,
            actions: [
                UNNotificationAction(identifier: openActionID, title: AlertCopy.open, options: [.foreground]),
                UNNotificationAction(identifier: snoozeActionID, title: AlertCopy.snooze, options: []),
            ],
            intentIdentifiers: [],
            options: []
        )
    }

    static func makeRequest(_ request: AlertRequest, calendar: Calendar = .current) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        content.categoryIdentifier = categoryID
        var userInfo = [alertKey: request.id]
        if let priorityID = request.priorityID {
            userInfo[priorityKey] = priorityID
        }
        content.userInfo = userInfo
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: request.fireAt),
            repeats: false
        )
        return UNNotificationRequest(identifier: request.id, content: content, trigger: trigger)
    }

    static func alertRequest(from request: UNNotificationRequest, calendar: Calendar = .current) -> AlertRequest? {
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
              let fireAt = calendar.date(from: trigger.dateComponents)
        else {
            return nil
        }
        return AlertRequest(
            id: request.identifier,
            title: request.content.title,
            body: request.content.body,
            fireAt: fireAt,
            priorityID: request.content.userInfo[priorityKey] as? String
        )
    }

    static func response(actionID: String, alertID: String, userInfo: [AnyHashable: Any]) -> AlertResponse? {
        let action: AlertAction
        switch actionID {
        case UNNotificationDefaultActionIdentifier, openActionID: action = .open
        case snoozeActionID: action = .snooze
        default: return nil
        }
        return AlertResponse(alertID: alertID, priorityID: userInfo[priorityKey] as? String, action: action)
    }
}

final class AlertNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    @MainActor weak var handler: (any AlertEventHandler)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let id = notification.request.identifier
        await MainActor.run { handler?.alertWasPresented(id: id) }
        return [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let request = response.notification.request
        guard let answer = SystemNotificationCenter.response(
            actionID: response.actionIdentifier,
            alertID: request.identifier,
            userInfo: request.content.userInfo
        ) else {
            return
        }
        await MainActor.run { handler }?.alertWasAnswered(answer)
    }
}
