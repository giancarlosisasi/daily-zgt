import Foundation

enum DueFilter: Hashable, Codable, Sendable {
    case today
    case tomorrow
    case week
    case overdue
    case noDate
    case all
    case day(String)
    case range(String, String)

    static let quickOptions: [DueFilter] = [.today, .tomorrow, .week, .overdue, .noDate, .all]
}

struct DueGroup: Equatable, Identifiable, Sendable {
    let id: String
    let title: String?
    let priorities: [Priority]
}

struct DueDays {
    let now: Date
    let calendar: Calendar

    init(now: Date, timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timeZone
        self.now = now
        self.calendar = calendar
    }

    var today: Date { calendar.startOfDay(for: now) }
    var tomorrow: Date { shift(today, by: 1) }
    var weekStart: Date { calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today }

    func shift(_ day: Date, by days: Int) -> Date {
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
        let moved = calendar.date(byAdding: .day, value: days, to: noon) ?? noon
        return calendar.startOfDay(for: moved)
    }

    func key(of date: Date) -> String {
        LocalTime.dayKey(for: date, in: calendar.timeZone)
    }

    func start(of key: String) -> Date? {
        LocalTime.day(from: key, in: calendar.timeZone)
    }

    func dayCount(from first: Date, to second: Date) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: first), to: calendar.startOfDay(for: second)).day ?? 0
    }
}

extension DueFilter {
    var isSingleDay: Bool {
        switch self {
        case .today, .tomorrow, .day: true
        default: false
        }
    }

    func resolved(_ days: DueDays) -> DueFilter {
        switch self {
        case let .day(key):
            if key == days.key(of: days.today) { return .today }
            if key == days.key(of: days.tomorrow) { return .tomorrow }
            return self
        case let .range(first, last):
            return first <= last ? self : .range(last, first)
        default:
            return self
        }
    }

    func span(_ days: DueDays) -> Range<Date>? {
        switch resolved(days) {
        case .today:
            return days.today..<days.tomorrow
        case .tomorrow:
            return days.tomorrow..<days.shift(days.today, by: 2)
        case .week:
            return days.weekStart..<days.shift(days.weekStart, by: 7)
        case let .day(key):
            return days.start(of: key).map { $0..<days.shift($0, by: 1) }
        case let .range(first, last):
            guard let start = days.start(of: first), let end = days.start(of: last) else { return nil }
            return start..<days.shift(end, by: 1)
        case .overdue, .noDate, .all:
            return nil
        }
    }

    func includes(_ priority: Priority, _ days: DueDays) -> Bool {
        let due = priority.dueAt
        switch resolved(days) {
        case .today:
            return due.map { $0 < days.tomorrow } ?? true
        case .overdue:
            return due.map { $0 < days.now } ?? false
        case .noDate:
            return due == nil
        case .all:
            return true
        default:
            guard let due, let span = span(days) else { return false }
            return span.contains(due)
        }
    }

    func counts(_ priority: Priority, _ days: DueDays) -> Bool {
        guard includes(priority, days) else { return false }
        return resolved(days) == .today ? priority.dueAt != nil : true
    }

    func groups(_ open: [Priority], _ days: DueDays) -> [DueGroup] {
        let shown = open.filter { includes($0, days) }
        switch resolved(days) {
        case .today:
            return Self.nonEmpty([
                DueGroup(id: "overdue", title: DueFilterLabels.overdueGroup, priorities: shown.filter { Self.isOverdue($0, days) }),
                DueGroup(id: "today", title: DueFilterLabels.todayGroup, priorities: shown.filter { $0.dueAt.map { $0 >= days.now } ?? false }),
                DueGroup(id: "noDate", title: DueFilterLabels.noDateGroup, priorities: shown.filter { $0.dueAt == nil }),
            ])
        case .all:
            let afterTomorrow = days.shift(days.today, by: 2)
            let today = shown.filter { priority in priority.dueAt.map { $0 >= days.now && $0 < days.tomorrow } ?? false }
            let tomorrow = shown.filter { priority in priority.dueAt.map { $0 >= days.tomorrow && $0 < afterTomorrow } ?? false }
            let later = shown.filter { priority in priority.dueAt.map { $0 >= afterTomorrow } ?? false }
            return Self.nonEmpty(
                [
                    DueGroup(id: "overdue", title: DueFilterLabels.overdueGroup, priorities: shown.filter { Self.isOverdue($0, days) }),
                    DueGroup(id: "today", title: DueFilterLabels.todayGroup, priorities: today),
                    DueGroup(id: "tomorrow", title: DueFilterLabels.tomorrowGroup, priorities: tomorrow),
                ]
                + Self.dayGroups(later, days)
                + [DueGroup(id: "noDate", title: DueFilterLabels.noDateGroup, priorities: shown.filter { $0.dueAt == nil })]
            )
        case .week, .range, .overdue:
            return Self.dayGroups(shown, days)
        default:
            return Self.nonEmpty([DueGroup(id: "list", title: nil, priorities: shown)])
        }
    }

    func open(_ open: [Priority], _ days: DueDays) -> [Priority] {
        groups(open, days).flatMap(\.priorities)
    }

    func counted(_ open: [Priority], _ days: DueDays) -> [Priority] {
        self.open(open, days).filter { counts($0, days) }
    }

    func hiddenOverdueCount(_ open: [Priority], _ days: DueDays) -> Int {
        switch resolved(days) {
        case .today, .overdue, .all:
            return 0
        default:
            return open.filter { Self.isOverdue($0, days) && !includes($0, days) }.count
        }
    }

    func showsDone(_ priority: Priority, _ days: DueDays) -> Bool {
        guard let doneAt = priority.doneAt else { return false }
        switch resolved(days) {
        case .overdue, .noDate, .all:
            return doneAt > DoneWindow.cutoff(now: days.now)
        default:
            return span(days)?.contains(doneAt) ?? false
        }
    }

    func stepped(by offset: Int, _ days: DueDays) -> DueFilter? {
        guard isSingleDay, let start = span(days)?.lowerBound else { return nil }
        return DueFilter.day(days.key(of: days.shift(start, by: offset))).resolved(days)
    }

    func newDue(_ days: DueDays) -> Date? {
        guard let span = span(days) else { return nil }
        let day: Date
        switch resolved(days) {
        case .today:
            return nil
        case .week, .range:
            let first = max(span.lowerBound, days.today)
            day = first < span.upperBound ? first : span.lowerBound
        default:
            day = span.lowerBound
        }
        return DueParts.join(day: day, time: NewPriorityDraft.defaultDue(after: days.now, calendar: days.calendar), calendar: days.calendar)
    }

    static func home(for priority: Priority, _ days: DueDays) -> DueFilter {
        guard !DueFilter.today.includes(priority, days), let due = priority.dueAt else { return .today }
        return DueFilter.day(days.key(of: due)).resolved(days)
    }

    static func picked(day: Date, _ days: DueDays) -> DueFilter {
        DueFilter.day(days.key(of: day)).resolved(days)
    }

    static func picked(from first: Date, to last: Date, _ days: DueDays) -> DueFilter {
        DueFilter.range(days.key(of: first), days.key(of: last)).resolved(days)
    }

    static func isOverdue(_ priority: Priority, _ days: DueDays) -> Bool {
        priority.dueAt.map { $0 < days.now } ?? false
    }

    private static func dayGroups(_ priorities: [Priority], _ days: DueDays) -> [DueGroup] {
        let dated = priorities.compactMap { priority in priority.dueAt.map { (days.key(of: $0), priority) } }
        let byDay = Dictionary(grouping: dated, by: \.0)
        return byDay.keys.sorted().map { key in
            DueGroup(id: key, title: DueFilterLabels.dayGroup(key, days), priorities: byDay[key, default: []].map(\.1))
        }
    }

    private static func nonEmpty(_ groups: [DueGroup]) -> [DueGroup] {
        groups.filter { !$0.priorities.isEmpty }
    }
}

struct RangePick: Equatable {
    private(set) var first: Date?

    mutating func pick(_ day: Date) -> (Date, Date)? {
        guard let start = first else {
            first = day
            return nil
        }
        first = nil
        return start <= day ? (start, day) : (day, start)
    }

    mutating func reset() {
        first = nil
    }
}

enum CalendarClick {
    static func isMonthStep(from old: Date, to new: Date, calendar: Calendar) -> Bool {
        let first = calendar.dateComponents([.year, .month, .day], from: old)
        let second = calendar.dateComponents([.year, .month, .day], from: new)
        guard let firstYear = first.year, let firstMonth = first.month, let firstDay = first.day,
              let secondYear = second.year, let secondMonth = second.month, let secondDay = second.day
        else {
            return false
        }
        guard abs((secondYear - firstYear) * 12 + secondMonth - firstMonth) == 1 else { return false }
        if firstDay == secondDay { return true }
        let lastDay = calendar.range(of: .day, in: .month, for: new)?.count ?? 0
        return secondDay == lastDay && firstDay > secondDay
    }
}
