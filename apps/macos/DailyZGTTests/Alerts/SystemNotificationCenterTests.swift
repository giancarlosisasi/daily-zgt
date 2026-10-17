import Foundation
import Testing
import UserNotifications
@testable import DailyZGT

@Suite
struct SystemNotificationCenterTests {
    private let sample = AlertRequest(
        id: "alert-1",
        title: "Vence en 30 min",
        body: "Terminar el brief de Tailwind v4",
        fireAt: localDate("2026-10-12T15:30:00"),
        priorityID: "priority-1"
    )

    @Test
    func theRequestCarriesTheCopyTheSoundTheCategoryAndTheIDs() throws {
        let request = SystemNotificationCenter.makeRequest(sample)
        #expect(request.identifier == "alert-1")
        #expect(request.content.title == "Vence en 30 min")
        #expect(request.content.body == "Terminar el brief de Tailwind v4")
        #expect(request.content.sound == UNNotificationSound.default)
        #expect(request.content.categoryIdentifier == SystemNotificationCenter.categoryID)
        #expect(request.content.userInfo["alert_id"] as? String == "alert-1")
        #expect(request.content.userInfo["priority_id"] as? String == "priority-1")
    }

    @Test
    func theTriggerIsACalendarTriggerAtTheFireTimeWithNoRepeat() throws {
        let request = SystemNotificationCenter.makeRequest(sample)
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(!trigger.repeats)
        #expect(trigger.dateComponents.year == 2026)
        #expect(trigger.dateComponents.month == 10)
        #expect(trigger.dateComponents.day == 12)
        #expect(trigger.dateComponents.hour == 15)
        #expect(trigger.dateComponents.minute == 30)
        #expect(trigger.dateComponents.second == 0)
    }

    @Test
    func aRequestReadBackFromMacOSIsEqualToTheOneThatWasAdded() {
        let request = SystemNotificationCenter.makeRequest(sample)
        #expect(SystemNotificationCenter.alertRequest(from: request) == sample)
    }

    @Test
    func aTestAlertHasNoPriorityID() {
        var test = sample
        test.id = AlertRequest.testID
        test.priorityID = nil
        let request = SystemNotificationCenter.makeRequest(test)
        #expect(request.content.userInfo["priority_id"] == nil)
        #expect(SystemNotificationCenter.alertRequest(from: request) == test)
    }

    @Test
    func aRequestWithAnotherTriggerIsNotAnAlertRequest() {
        let request = UNNotificationRequest(
            identifier: "other",
            content: UNMutableNotificationContent(),
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        )
        #expect(SystemNotificationCenter.alertRequest(from: request) == nil)
    }

    @Test
    func theCategoryHasTheTwoActionsInOrder() {
        let category = SystemNotificationCenter.makeCategory()
        #expect(category.identifier == "priority-alert")
        #expect(category.actions.map(\.title) == ["Abrir", "Posponer 15 min"])
        #expect(category.actions.map(\.identifier) == ["open", "snooze"])
        #expect(category.actions[0].options.contains(.foreground))
        #expect(!category.actions[1].options.contains(.foreground))
    }

    @Test
    func theDefaultClickAndTheOpenActionAreTheOpenAction() {
        let userInfo: [AnyHashable: Any] = ["alert_id": "alert-1", "priority_id": "priority-1"]
        let expected = AlertResponse(alertID: "alert-1", priorityID: "priority-1", action: .open)
        #expect(SystemNotificationCenter.response(
            actionID: UNNotificationDefaultActionIdentifier,
            alertID: "alert-1",
            userInfo: userInfo
        ) == expected)
        #expect(SystemNotificationCenter.response(actionID: "open", alertID: "alert-1", userInfo: userInfo) == expected)
    }

    @Test
    func theSnoozeActionIsTheSnoozeAction() {
        let response = SystemNotificationCenter.response(
            actionID: "snooze",
            alertID: "alert-1",
            userInfo: ["priority_id": "priority-1"]
        )
        #expect(response == AlertResponse(alertID: "alert-1", priorityID: "priority-1", action: .snooze))
    }

    @Test
    func aDismissIsNoAction() {
        let response = SystemNotificationCenter.response(
            actionID: UNNotificationDismissActionIdentifier,
            alertID: "alert-1",
            userInfo: [:]
        )
        #expect(response == nil)
    }

    @Test
    func aTestAlertAnswerHasNoPriority() {
        let response = SystemNotificationCenter.response(actionID: "open", alertID: AlertRequest.testID, userInfo: [:])
        #expect(response == AlertResponse(alertID: "test-alert", priorityID: nil, action: .open))
    }
}
