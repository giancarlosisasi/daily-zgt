import Foundation

enum DoneWindow {
    static let length: TimeInterval = 24 * 60 * 60

    static func cutoff(now: Date) -> Date {
        LocalTime.truncated(now).addingTimeInterval(-length)
    }
}

struct DoneDayGroup: Equatable, Identifiable {
    let day: String
    let date: Date
    let priorities: [Priority]

    var id: String { day }
}

enum DoneHistory {
    static func groups(from priorities: [Priority], in timeZone: TimeZone = .current) -> [DoneDayGroup] {
        let dated = priorities.compactMap { priority in priority.doneAt.map { (priority, $0) } }
        let byDay = Dictionary(grouping: dated) { LocalTime.dayKey(for: $0.1, in: timeZone) }
        return byDay
            .map { day, entries in
                let sorted = entries.sorted { first, second in
                    if first.1 != second.1 { return first.1 > second.1 }
                    if first.0.position != second.0.position { return first.0.position > second.0.position }
                    return first.0.id < second.0.id
                }
                return DoneDayGroup(day: day, date: sorted[0].1, priorities: sorted.map(\.0))
            }
            .sorted { $0.day > $1.day }
    }
}
