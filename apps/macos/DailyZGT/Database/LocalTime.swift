import Foundation

enum LocalTime {
    static func text(from date: Date, in timeZone: TimeZone = .current) -> String {
        date.formatted(timestampStyle(timeZone))
    }

    static func date(from text: String, in timeZone: TimeZone = .current) -> Date? {
        try? Date(text, strategy: timestampStyle(timeZone))
    }

    static func truncated(_ date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate.rounded(.down))
    }

    static func dayKey(for date: Date, in timeZone: TimeZone = .current) -> String {
        date.formatted(Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day().dateSeparator(.dash))
    }

    static func weekKey(for date: Date, in timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d", components.yearForWeekOfYear ?? 0, components.weekOfYear ?? 0)
    }

    private static func timestampStyle(_ timeZone: TimeZone) -> Date.ISO8601FormatStyle {
        Date.ISO8601FormatStyle(timeZone: timeZone)
            .year().month().day().dateSeparator(.dash)
            .time(includingFractionalSeconds: false).timeSeparator(.colon)
    }
}
