import Foundation

enum TodayEntry {
    static func enteredAt(events: [PriorityEvent]) -> Date? {
        events
            .filter { $0.type == .created || $0.type == .moved }
            .max { ($0.at, $0.id ?? 0) < ($1.at, $1.id ?? 0) }?
            .at
    }

    static func chip(enteredAt entered: Date?, now: Date, calendar: Calendar = .current) -> DueChipState? {
        guard let entered else { return nil }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: entered),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        switch days {
        case ..<1:
            return nil
        case 1:
            return DueChipState(label: "De ayer", tone: .later)
        default:
            let weekday = DueChipState.weekdays[calendar.component(.weekday, from: entered) - 1]
            return DueChipState(label: "Desde \(weekday) \(calendar.component(.day, from: entered))", tone: .later)
        }
    }

    static func chip(events: [PriorityEvent], now: Date, calendar: Calendar = .current) -> DueChipState? {
        chip(enteredAt: enteredAt(events: events), now: now, calendar: calendar)
    }

    @MainActor
    static func events(for list: PriorityList, in store: AppStore) -> [Priority.ID: [PriorityEvent]] {
        list == .today ? ((try? store.enteringEvents(in: .today)) ?? [:]) : [:]
    }

    static func chips(
        events: [Priority.ID: [PriorityEvent]],
        now: Date,
        calendar: Calendar = .current
    ) -> [Priority.ID: DueChipState] {
        events.compactMapValues { chip(events: $0, now: now, calendar: calendar) }
    }
}
