import Foundation
import Testing
@testable import DailyZGT

@Suite
struct AlertCopyTests {
    let due = localDate("2026-10-12T16:00:00")

    private func title(at fireAt: String) -> String {
        AlertCopy.title(fireAt: localDate(fireAt), due: due)
    }

    @Test
    func theAlertBeforeTheDueSaysVenceEn30Min() {
        #expect(title(at: "2026-10-12T15:30:00") == "Vence en 30 min")
    }

    @Test
    func theAlertAtTheDueSaysPrioridadVencida() {
        #expect(title(at: "2026-10-12T16:00:00") == "Prioridad vencida")
    }

    @Test
    func anAlertAfterTheDueSaysPrioridadVencida() {
        #expect(title(at: "2026-10-12T16:15:00") == "Prioridad vencida")
    }

    @Test
    func aSnoozeBeforeTheDueSaysTheMinutesThatAreLeft() {
        #expect(title(at: "2026-10-12T15:48:00") == "Vence en 12 min")
        #expect(title(at: "2026-10-12T15:59:00") == "Vence en 1 min")
    }

    @Test
    func lessThanHalfAMinuteBeforeTheDueSaysPrioridadVencida() {
        #expect(title(at: "2026-10-12T15:59:40") == "Prioridad vencida")
    }

    @Test
    func aLongWaitUsesTheTextOfTheDueChip() {
        #expect(title(at: "2026-10-12T14:40:00") == "Vence en 1 h 20 min")
        #expect(title(at: "2026-10-12T11:00:00") == "Vence hoy 16:00")
        #expect(title(at: "2026-10-09T11:00:00") == "Vence lun 16:00")
    }

    @Test
    func theRequestOfAnAlertHasTheTitleOfThePriorityAsBody() throws {
        let priority = alertPriority(due: "2026-10-12T16:00:00", title: "Terminar el brief")
        let request = try #require(AlertRequest(
            alert: alertRow("a1", .before30m, at: "2026-10-12T15:30:00"),
            priority: priority
        ))
        #expect(request == AlertRequest(
            id: "a1",
            title: "Vence en 30 min",
            body: "Terminar el brief",
            fireAt: localDate("2026-10-12T15:30:00"),
            priorityID: "p1"
        ))
    }

    @Test
    func aPriorityWithNoDueHasNoRequest() {
        let request = AlertRequest(
            alert: alertRow("a1", .atDue, at: "2026-10-12T16:00:00"),
            priority: alertPriority(due: nil)
        )
        #expect(request == nil)
    }

    @Test
    func theTestAlertHasItsOwnIDAndTheBodyOfThePrototype() {
        #expect(AlertRequest.test(fireAt: due) == AlertRequest(
            id: "test-alert",
            title: "Prioridad vencida",
            body: "Revisa tu lista de hoy",
            fireAt: due,
            priorityID: nil
        ))
    }
}
