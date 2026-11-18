import Foundation

enum DueFilterLabels {
    static let overdueGroup = "Vencidas"
    static let todayGroup = "Hoy"
    static let tomorrowGroup = "Mañana"
    static let noDateGroup = "Sin fecha"
    static let filterKey = "Filtrar por fecha"
    static let previousDay = "Día anterior"
    static let nextDay = "Día siguiente"
    static let pickDay = "Elegir fecha"
    static let pickRange = "Rango"
    static let rangeFirstHint = "Elige el primer día."
    static let rangeLastHint = "Elige el último día."
    static let allDone = "Todo listo para hoy"
    static let showOverdue = "Ver"

    private static let weekdays = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
    private static let months = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]

    static func option(_ filter: DueFilter) -> String {
        switch filter {
        case .today: "Hoy"
        case .tomorrow: "Mañana"
        case .week: "Esta semana"
        case .overdue: "Vencidas"
        case .noDate: "Sin fecha"
        case .all: "Todas"
        case .day: pickDay
        case .range: pickRange
        }
    }

    static func title(_ filter: DueFilter, _ days: DueDays) -> String {
        switch filter.resolved(days) {
        case let .day(key):
            return days.start(of: key).map { dayText($0, days) } ?? key
        case let .range(first, last):
            guard let start = days.start(of: first), let end = days.start(of: last) else { return option(filter) }
            return rangeText(start, end, days, separator: " – ")
        case let resolved:
            return option(resolved)
        }
    }

    static func subtitle(_ filter: DueFilter, _ days: DueDays, openCount: Int) -> String? {
        switch filter.resolved(days) {
        case .today:
            return dayText(days.today, days)
        case .tomorrow:
            return dayText(days.tomorrow, days)
        case .week:
            return rangeText(days.weekStart, days.shift(days.weekStart, by: 6), days, separator: "–")
        case .overdue:
            return "antes de hoy"
        case .noDate:
            return nil
        case .all:
            return openCount == 1 ? "1 abierta" : "\(openCount) abiertas"
        case let .day(key):
            guard let day = days.start(of: key) else { return nil }
            let offset = days.dayCount(from: days.today, to: day)
            if offset == -1 { return "ayer" }
            return offset < 0 ? "hace \(-offset) días" : "en \(offset) días"
        case let .range(first, last):
            guard let start = days.start(of: first), let end = days.start(of: last) else { return nil }
            let count = days.dayCount(from: start, to: end) + 1
            return count == 1 ? "1 día" : "\(count) días"
        }
    }

    static func empty(_ filter: DueFilter, _ days: DueDays) -> String {
        switch filter.resolved(days) {
        case .today: return "Nada vence hoy."
        case .tomorrow: return "Nada vence mañana."
        case .week: return "Nada vence esta semana."
        case .overdue: return "Nada vencido."
        case .noDate: return "Cada prioridad tiene fecha."
        case .all: return "Nada pendiente."
        case let .day(key):
            return "Nada vence el \(days.start(of: key).map { dayText($0, days) } ?? key)."
        case let .range(first, last):
            guard let start = days.start(of: first), let end = days.start(of: last) else { return "Nada vence en el rango." }
            return "Nada vence entre el \(betweenText(start, end, days))."
        }
    }

    static func summary(_ filter: DueFilter, _ days: DueDays, done: Int, total: Int) -> String {
        "\(done) de \(total) hechas \(summarySuffix(filter, days))"
    }

    static func overdueLink(_ count: Int) -> String {
        count == 1 ? "1 vencida" : "\(count) vencidas"
    }

    static func dayGroup(_ key: String, _ days: DueDays) -> String {
        guard let day = days.start(of: key) else { return key }
        let parts = days.calendar.dateComponents([.weekday, .day, .month, .year], from: day)
        let now = days.calendar.dateComponents([.month, .year], from: days.today)
        let weekday = weekdays[(parts.weekday ?? 1) - 1].capitalized
        let sameMonth = parts.month == now.month && parts.year == now.year
        return sameMonth ? "\(weekday) \(parts.day ?? 0)" : "\(weekday) \(parts.day ?? 0) \(month(parts.month))"
    }

    static func dayText(_ day: Date, _ days: DueDays) -> String {
        let parts = days.calendar.dateComponents([.weekday, .day, .month], from: day)
        return "\(weekdays[(parts.weekday ?? 1) - 1]) \(parts.day ?? 0) \(month(parts.month))"
    }

    private static func summarySuffix(_ filter: DueFilter, _ days: DueDays) -> String {
        switch filter.resolved(days) {
        case .today: return "hoy"
        case .tomorrow: return "mañana"
        case .week: return "esta semana"
        case .range: return "en el rango"
        case .overdue, .noDate, .all: return "en 24 h"
        case let .day(key):
            guard let day = days.start(of: key) else { return "ese día" }
            let parts = days.calendar.dateComponents([.weekday, .day], from: day)
            return "el \(weekdays[(parts.weekday ?? 1) - 1]) \(parts.day ?? 0)"
        }
    }

    private static func rangeText(_ start: Date, _ end: Date, _ days: DueDays, separator: String) -> String {
        let first = days.calendar.dateComponents([.day, .month, .year], from: start)
        let last = days.calendar.dateComponents([.day, .month, .year], from: end)
        if first.year != last.year {
            return "\(first.day ?? 0) \(month(first.month)) \(first.year ?? 0)\(separator)\(last.day ?? 0) \(month(last.month)) \(last.year ?? 0)"
        }
        if first.month != last.month {
            return "\(first.day ?? 0) \(month(first.month))\(separator)\(last.day ?? 0) \(month(last.month))"
        }
        return "\(first.day ?? 0)\(separator)\(last.day ?? 0) \(month(last.month))"
    }

    private static func betweenText(_ start: Date, _ end: Date, _ days: DueDays) -> String {
        let first = days.calendar.dateComponents([.day, .month, .year], from: start)
        let last = days.calendar.dateComponents([.day, .month, .year], from: end)
        if first.month == last.month && first.year == last.year {
            return "\(first.day ?? 0) y el \(last.day ?? 0) \(month(last.month))"
        }
        return "\(first.day ?? 0) \(month(first.month)) y el \(last.day ?? 0) \(month(last.month))"
    }

    private static func month(_ number: Int?) -> String {
        months[((number ?? 1) - 1 + 12) % 12]
    }
}
