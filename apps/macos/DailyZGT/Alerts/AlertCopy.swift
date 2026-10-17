import Foundation
import os

enum AlertCopy {
    static let overdue = "Prioridad vencida"
    static let testBody = "Revisa tu lista de hoy"
    static let open = "Abrir"
    static let snooze = "Posponer 15 min"
    static let test = "Probar alerta"
    static let off = "Las alertas están desactivadas."
    static let openSettings = "Abrir ajustes"

    static func title(fireAt: Date, due: Date, calendar: Calendar = .current) -> String {
        guard due.timeIntervalSince(fireAt) >= 30,
              let chip = DueChipState.make(due: due, now: fireAt, calendar: calendar)
        else {
            return overdue
        }
        return "Vence " + chip.label.prefix(1).lowercased() + chip.label.dropFirst()
    }
}

extension AlertRequest {
    init?(alert: PriorityAlert, priority: Priority, calendar: Calendar = .current) {
        guard let due = priority.dueAt else { return nil }
        self.init(
            id: alert.id,
            title: AlertCopy.title(fireAt: alert.fireAt, due: due, calendar: calendar),
            body: priority.title,
            fireAt: alert.fireAt,
            priorityID: priority.id
        )
    }

    static func test(fireAt: Date) -> AlertRequest {
        AlertRequest(id: testID, title: AlertCopy.overdue, body: AlertCopy.testBody, fireAt: fireAt, priorityID: nil)
    }
}

enum AlertLog {
    static let logger = Logger(subsystem: "com.giancarlosisasi.dailyzgt", category: "alerts")
}
