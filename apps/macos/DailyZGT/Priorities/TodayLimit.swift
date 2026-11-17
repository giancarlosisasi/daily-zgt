import Foundation

enum TodayLimit {
    static let maxOpen = 5
    static let message = "Hoy ya tiene \(maxOpen) prioridades abiertas."
    static let key = AppStateKey(name: "today_limit", defaultValue: false)

    static func blocksAdd(isOn: Bool, openCount: Int) -> Bool {
        isOn && openCount >= maxOpen
    }

    static func landsInToday(due: Date?, _ days: DueDays) -> Bool {
        due.map { $0 < days.tomorrow } ?? true
    }
}

extension AppStore {
    var todayLimitIsOn: Bool {
        value(for: TodayLimit.key)
    }

    func addBlock(forDue due: Date?) -> String? {
        guard TodayLimit.landsInToday(due: due, dueDays) else { return nil }
        return TodayLimit.blocksAdd(isOn: todayLimitIsOn, openCount: openCount(in: .today)) ? TodayLimit.message : nil
    }

    func dueChangeBlock(for id: Priority.ID, to due: Date?) -> String? {
        guard due != nil else { return nil }
        let days = dueDays
        let wasCounted = priority(id: id).map { !$0.isDone && DueFilter.today.counts($0, days) } ?? false
        return wasCounted ? nil : addBlock(forDue: due)
    }
}
