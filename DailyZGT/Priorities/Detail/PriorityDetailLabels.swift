import Foundation

extension PriorityList {
    var title: String {
        switch self {
        case .today: "Hoy"
        case .week: "Semana"
        }
    }
}

extension RepeatRule {
    var title: String {
        switch self {
        case .none: "No"
        case .daily: "Cada día"
        }
    }
}

enum PriorityDetailLabels {
    private static let weekdays = ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"]
    private static let months = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]

    static func created(_ createdAt: Date, now: Date, calendar: Calendar = .current) -> String {
        if calendar.isDate(createdAt, inSameDayAs: now) {
            return "Creada hoy"
        }
        let parts = calendar.dateComponents([.weekday, .day, .month, .hour, .minute], from: createdAt)
        let weekday = weekdays[(parts.weekday ?? 1) - 1]
        let month = months[(parts.month ?? 1) - 1]
        let time = String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
        return "Creada \(weekday) \(parts.day ?? 0) \(month) · \(time)"
    }

    static func alert(due: Date?) -> String {
        due == nil ? "Sin fecha, sin alerta" : "30 min antes y al vencer"
    }

    static func state(of priority: Priority) -> String {
        priority.isDone ? "Hecha" : "Pendiente"
    }

    static func subtasks(_ progress: SubtaskProgress) -> String? {
        progress.total > 0 ? "\(progress.done)/\(progress.total) subtareas" : nil
    }
}
