import Foundation

@MainActor
enum PanelLabels {
    static func date(for list: PriorityList, at date: Date, in timeZone: TimeZone = .current) -> String {
        switch list {
        case .today: dayLabel(for: date, in: timeZone)
        case .week: weekLabel(for: date, in: timeZone)
        }
    }

    static func summary(for list: PriorityList, store: AppStore, now: Date? = nil) -> String {
        let start = DoneWindow.periodStart(for: list, at: now ?? store.now())
        let done = (try? store.doneCount(in: list, from: start)) ?? 0
        let total = done + store.openCount(in: list)
        let suffix = list == .today ? "hoy" : "esta semana"
        return "\(done) de \(total) hechas \(suffix)"
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

    private static func weekLabel(for date: Date, in timeZone: TimeZone) -> String {
        let calendar = calendar(in: timeZone)
        let week = calendar.component(.weekOfYear, from: date)
        guard let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start,
              let end = calendar.date(byAdding: .day, value: 6, to: start)
        else {
            return "Semana \(week)"
        }
        let first = calendar.dateComponents([.day, .month], from: start)
        let last = calendar.dateComponents([.day, .month], from: end)
        let firstMonth = months[(first.month ?? 1) - 1]
        let lastMonth = months[(last.month ?? 1) - 1]
        let range = first.month == last.month
            ? "\(first.day ?? 0)–\(last.day ?? 0) \(lastMonth)"
            : "\(first.day ?? 0) \(firstMonth)–\(last.day ?? 0) \(lastMonth)"
        return "Semana \(week) · \(range)"
    }
}
