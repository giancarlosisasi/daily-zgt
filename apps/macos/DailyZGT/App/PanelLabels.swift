import Foundation

@MainActor
enum PanelLabels {
    static func summary(for filter: DueFilter, store: AppStore, now: Date? = nil) -> String {
        let days = DueDays(now: now ?? store.now())
        let done = store.donePriorities(in: filter, days: days).count
        let total = done + store.openCount(in: filter, days: days)
        return DueFilterLabels.summary(filter, days, done: done, total: total)
    }

    static func historyDay(for date: Date, now: Date, in timeZone: TimeZone = .current) -> String {
        let calendar = calendar(in: timeZone)
        if calendar.isDate(date, inSameDayAs: now) {
            return "Hoy"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "Ayer"
        }
        return dayLabel(for: date, in: timeZone)
    }

    private static let weekdays = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"]
    private static let months = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]

    private static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timeZone
        return calendar
    }

    private static func dayLabel(for date: Date, in timeZone: TimeZone) -> String {
        let calendar = calendar(in: timeZone)
        let parts = calendar.dateComponents([.weekday, .day, .month], from: date)
        return "\(weekdays[(parts.weekday ?? 1) - 1]) \(parts.day ?? 0) \(months[(parts.month ?? 1) - 1])"
    }
}
