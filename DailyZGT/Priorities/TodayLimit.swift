import Foundation

enum TodayLimit {
    static let maxOpen = 5
    static let message = "Hoy ya tiene \(maxOpen) prioridades abiertas."
    static let key = AppStateKey(name: "today_limit", defaultValue: false)

    static func blocksAdd(isOn: Bool, openCount: Int) -> Bool {
        isOn && openCount >= maxOpen
    }
}

extension AppStore {
    var todayLimitIsOn: Bool {
        value(for: TodayLimit.key)
    }

    func canAddToToday() -> Bool {
        !TodayLimit.blocksAdd(isOn: todayLimitIsOn, openCount: openCount(in: .today))
    }

    func todayAddBlock() -> String? {
        canAddToToday() ? nil : TodayLimit.message
    }
}
