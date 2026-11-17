import Foundation

extension DueFilter {
    static func yesterday(_ days: DueDays) -> DueFilter {
        .day(days.key(of: days.shift(days.today, by: -1)))
    }

    static func noteOptions(_ days: DueDays) -> [DueFilter] {
        [.all, .today, yesterday(days), .week]
    }

    static func noteStart(stored: DueFilter?, legacyScope: NoteScope?) -> DueFilter {
        stored ?? (legacyScope == .week ? .week : .today)
    }

    func includesNote(_ note: NoteItem, _ days: DueDays) -> Bool {
        guard let span = span(days) else { return true }
        return span.contains(note.createdAt)
    }

    func noteStepped(by offset: Int, _ days: DueDays) -> DueFilter? {
        guard let next = stepped(by: offset, days), let start = next.span(days)?.lowerBound else { return nil }
        return start <= days.today ? next : nil
    }
}

enum NoteFilterLabels {
    static let newNote = "Nueva nota"
    static let emptyDetail = "Elige una nota para leerla y editarla."
    static let untitled = "Nota vacía"
    static let imageOnly = "Imagen"
    static let placeholder = "Escribe en Markdown"
    static let saveHint = "Se guarda al escribir."
    static let saveFailed = "No se pudo guardar la nota."
    static let deleteNote = "Eliminar nota"
    static let deleted = "Borrada"

    static func option(_ filter: DueFilter, _ days: DueDays) -> String {
        filter == .yesterday(days) ? "Ayer" : DueFilterLabels.option(filter)
    }

    static func subtitle(_ filter: DueFilter, _ days: DueDays, count: Int) -> String? {
        switch filter.resolved(days) {
        case .today:
            return "\(DueFilterLabels.dayText(days.today, days)) · creadas hoy"
        case .week:
            let range = DueFilterLabels.subtitle(.week, days, openCount: 0) ?? ""
            return "\(range) · creadas esta semana"
        case .all, .overdue, .noDate:
            return count == 1 ? "1 nota" : "\(count) notas"
        case let .day(key):
            guard let day = days.start(of: key) else { return nil }
            let offset = days.dayCount(from: days.today, to: day)
            if offset == -1 { return "creadas ayer" }
            return offset < 0 ? "creadas hace \(-offset) días" : "en \(offset) días"
        case .tomorrow, .range:
            return DueFilterLabels.subtitle(filter, days, openCount: count)
        }
    }

    static func empty(_ filter: DueFilter, _ days: DueDays) -> String {
        switch filter.resolved(days) {
        case .today: return "Sin notas de hoy."
        case .tomorrow: return "Sin notas de mañana."
        case .week: return "Sin notas de esta semana."
        case .all, .overdue, .noDate: return "Sin notas."
        case .range: return "Sin notas en este rango."
        case let .day(key):
            return "Sin notas del \(days.start(of: key).map { DueFilterLabels.dayText($0, days) } ?? key)."
        }
    }

    private static let weekdays = ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"]
    private static let months = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]

    static func rowDate(_ createdAt: Date, _ days: DueDays) -> String {
        let calendar = days.calendar
        let parts = calendar.dateComponents([.year, .weekday, .day, .month, .hour, .minute], from: createdAt)
        if calendar.isDate(createdAt, inSameDayAs: days.now) {
            return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
        }
        let age = days.dayCount(from: createdAt, to: days.today)
        if age > 0 && age < 7 {
            return "\(weekdays[(parts.weekday ?? 1) - 1]) \(parts.day ?? 0)"
        }
        let month = months[((parts.month ?? 1) - 1 + 12) % 12]
        let thisYear = calendar.component(.year, from: days.now)
        return parts.year == thisYear ? "\(parts.day ?? 0) \(month)" : "\(parts.day ?? 0) \(month) \(parts.year ?? 0)"
    }

    static func meta(_ note: NoteItem, _ days: DueDays) -> String {
        let calendar = days.calendar
        let parts = calendar.dateComponents([.weekday, .day, .month, .hour, .minute], from: note.createdAt)
        let created = "Creada \(weekdays[(parts.weekday ?? 1) - 1]) \(parts.day ?? 0) \(months[((parts.month ?? 1) - 1 + 12) % 12])"
            + " · " + String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
        let edited = note.updatedAt.timeIntervalSince(note.createdAt)
        guard edited >= 60 else { return created }
        return "\(created) · \(editedText(note.updatedAt, days))"
    }

    private static func editedText(_ updatedAt: Date, _ days: DueDays) -> String {
        let minutes = Int(days.now.timeIntervalSince(updatedAt) / 60)
        if minutes < 1 { return "Editada ahora" }
        if minutes < 60 { return "Editada hace \(minutes) min" }
        let calendar = days.calendar
        let parts = calendar.dateComponents([.weekday, .day, .month, .hour, .minute], from: updatedAt)
        let time = String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
        if calendar.isDate(updatedAt, inSameDayAs: days.now) { return "Editada a las \(time)" }
        return "Editada \(weekdays[(parts.weekday ?? 1) - 1]) \(parts.day ?? 0) \(months[((parts.month ?? 1) - 1 + 12) % 12])"
    }
}
