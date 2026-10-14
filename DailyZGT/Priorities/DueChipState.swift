import Foundation

enum DueTone: Equatable, Sendable {
    case overdue
    case soon
    case later
}

struct DueChipState: Equatable, Sendable {
    let label: String
    let tone: DueTone

    static let weekdays = ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"]

    static func make(due: Date?, now: Date, calendar: Calendar = .current) -> DueChipState? {
        guard let due else { return nil }
        let minutes = Int((due.timeIntervalSince(now) / 60 + 0.5).rounded(.down))
        if minutes < 0 {
            return DueChipState(label: "Vencida", tone: .overdue)
        }
        if minutes < 120 {
            let label = minutes < 60 ? "En \(minutes) min" : "En \(minutes / 60) h \(minutes % 60) min"
            return DueChipState(label: label, tone: .soon)
        }
        let parts = calendar.dateComponents([.hour, .minute, .weekday], from: due)
        let time = String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
        if calendar.isDate(due, inSameDayAs: now) {
            return DueChipState(label: "Hoy \(time)", tone: .later)
        }
        return DueChipState(label: "\(weekdays[(parts.weekday ?? 1) - 1]) \(time)", tone: .later)
    }
}
