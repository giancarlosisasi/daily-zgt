import Foundation
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct AppStoreAlertTests {
    let clock = TestClock("2026-10-12T10:00:00")

    private func row(
        _ id: String,
        _ kind: AlertKind,
        at fireAt: String,
        priority: Priority.ID,
        status: AlertStatus = .scheduled
    ) -> PriorityAlert {
        PriorityAlert(id: id, priorityID: priority, kind: kind, fireAt: localDate(fireAt), status: status)
    }

    @Test
    func aStoreWithNoAlertGivesAnEmptyList() throws {
        #expect(try makeStore(clock).alerts().isEmpty)
    }

    @Test
    func savedAlertsComeBackInTheOrderOfTheFireTime() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "With due", list: .today)
        let late = row("a-late", .atDue, at: "2026-10-12T12:00:00", priority: priority.id)
        let early = row("z-early", .before30m, at: "2026-10-12T11:30:00", priority: priority.id)
        try store.saveAlerts([late, early])
        #expect(try store.alerts() == [early, late])
    }

    @Test
    func theFireTimeIsLocalTextInTheFile() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "With due", list: .today)
        try store.saveAlerts([row("a1", .atDue, at: "2026-10-12T12:00:00", priority: priority.id)])
        #expect(try values("SELECT fire_at FROM alert", in: store.database) == ["2026-10-12T12:00:00"])
        #expect(try values("SELECT kind FROM alert", in: store.database) == ["at_due"])
        #expect(try values("SELECT status FROM alert", in: store.database) == ["scheduled"])
    }

    @Test
    func aSaveOfAnIDThatExistsChangesTheFireTimeAndTheStatus() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "With due", list: .today)
        try store.saveAlerts([row("a1", .atDue, at: "2026-10-12T12:00:00", priority: priority.id)])
        let moved = row("a1", .atDue, at: "2026-10-12T15:00:00", priority: priority.id, status: .cancelled)
        try store.saveAlerts([moved])
        #expect(try store.alerts() == [moved])
    }

    @Test
    func anAlertOfAPriorityThatIsGoneIsNotSaved() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "With due", list: .today)
        let kept = row("a1", .atDue, at: "2026-10-12T12:00:00", priority: priority.id)
        try store.saveAlerts([row("a0", .atDue, at: "2026-10-12T12:00:00", priority: "missing"), kept])
        #expect(try store.alerts() == [kept])
    }

    @Test
    func theListCanKeepOnlyOneStatus() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "With due", list: .today)
        let scheduled = row("a1", .atDue, at: "2026-10-12T12:00:00", priority: priority.id)
        let delivered = row("a2", .before30m, at: "2026-10-12T11:30:00", priority: priority.id, status: .delivered)
        try store.saveAlerts([scheduled, delivered])
        #expect(try store.alerts(status: .scheduled) == [scheduled])
        #expect(try store.alerts(status: .delivered) == [delivered])
        #expect(try store.alerts(status: .snoozed).isEmpty)
    }

    @Test
    func oneAlertIsReadByItsID() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "With due", list: .today)
        let saved = row("a1", .snooze, at: "2026-10-12T10:15:00", priority: priority.id)
        try store.saveAlerts([saved])
        #expect(try store.alert(id: "a1") == saved)
        #expect(try store.alert(id: "missing") == nil)
    }

    @Test
    func aDeletedPriorityTakesItsAlertsWithIt() throws {
        let store = try makeStore(clock)
        let priority = try store.addPriority(title: "With due", list: .today)
        try store.saveAlerts([row("a1", .atDue, at: "2026-10-12T12:00:00", priority: priority.id)])
        try store.deletePriority(priority.id)
        #expect(try store.alerts().isEmpty)
    }

    @Test
    func anEmptySaveWritesNothing() throws {
        let store = try makeStore(clock)
        try store.saveAlerts([])
        #expect(try store.alerts().isEmpty)
    }
}
