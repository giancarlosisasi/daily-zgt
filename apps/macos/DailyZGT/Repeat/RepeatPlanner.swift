import Foundation

struct RepeatCopy: Equatable, Sendable {
    var sourceID: Priority.ID
    var seriesID: String
    var title: String
    var note: String
    var level: PriorityLevel
    var dueAt: Date?
    var subtaskTitles: [String]
}

enum RepeatPlanner {
    static func copies(
        of priorities: [Priority],
        subtasks: [Priority.ID: [Subtask]],
        now: Date,
        calendar: Calendar = .current
    ) -> [RepeatCopy] {
        let today = LocalTime.dayKey(for: now, in: calendar.timeZone)
        return Dictionary(grouping: priorities, by: \.seriesID).values
            .compactMap { series -> Priority? in
                guard series.allSatisfy(\.isDone),
                      let last = series.max(by: wasDoneBefore),
                      last.repeatRule == .daily,
                      let doneAt = last.doneAt,
                      LocalTime.dayKey(for: doneAt, in: calendar.timeZone) < today
                else {
                    return nil
                }
                return last
            }
            .sorted { ($0.position, $0.id) < ($1.position, $1.id) }
            .map { source in
                RepeatCopy(
                    sourceID: source.id,
                    seriesID: source.seriesID,
                    title: source.title,
                    note: source.note,
                    level: source.level,
                    dueAt: source.dueAt.flatMap { sameTime(as: $0, onTheDayOf: now, calendar: calendar) },
                    subtaskTitles: (subtasks[source.id] ?? [])
                        .sorted { ($0.position, $0.id) < ($1.position, $1.id) }
                        .map(\.title)
                )
            }
    }

    static func sameTime(as due: Date, onTheDayOf now: Date, calendar: Calendar = .current) -> Date? {
        let time = calendar.dateComponents([.hour, .minute, .second], from: due)
        return calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: now
        )
    }

    private static func wasDoneBefore(_ first: Priority, _ second: Priority) -> Bool {
        let firstDone = first.doneAt ?? .distantPast
        let secondDone = second.doneAt ?? .distantPast
        if firstDone != secondDone {
            return firstDone < secondDone
        }
        return (first.createdAt, first.position, first.id) < (second.createdAt, second.position, second.id)
    }
}
