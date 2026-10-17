import Foundation
import Testing
@testable import DailyZGT

func alertPriority(_ id: String = "p1", due: String?, done: Bool = false, title: String? = nil) -> Priority {
    let at = localDate("2026-10-12T09:00:00")
    return Priority(
        id: id,
        title: title ?? "Title \(id)",
        note: "",
        level: .medium,
        list: .today,
        dueAt: due.map(localDate),
        doneAt: done ? at : nil,
        position: 1,
        createdAt: at,
        updatedAt: at
    )
}

func alertRow(
    _ id: String,
    _ kind: AlertKind,
    at fireAt: String,
    priority: String = "p1",
    status: AlertStatus = .scheduled
) -> PriorityAlert {
    PriorityAlert(id: id, priorityID: priority, kind: kind, fireAt: localDate(fireAt), status: status)
}

@Suite
struct AlertPlannerTests {
    let now = localDate("2026-10-12T10:00:00")

    private func wanted(_ priorities: Priority...) -> [WantedAlert] {
        AlertPlanner.wanted(for: priorities, now: now)
    }

    private func alert(_ kind: AlertKind, at fireAt: String, priority: String = "p1") -> WantedAlert {
        WantedAlert(priorityID: priority, kind: kind, fireAt: localDate(fireAt))
    }

    @Test
    func aDueInTwoHoursWantsTheAlertBeforeAndTheAlertAtTheDue() {
        #expect(wanted(alertPriority(due: "2026-10-12T12:00:00")) == [
            alert(.before30m, at: "2026-10-12T11:30:00"),
            alert(.atDue, at: "2026-10-12T12:00:00"),
        ])
    }

    @Test
    func aDueIn29MinWantsOnlyTheAlertAtTheDue() {
        #expect(wanted(alertPriority(due: "2026-10-12T10:29:00")) == [alert(.atDue, at: "2026-10-12T10:29:00")])
    }

    @Test
    func aDueInExactly30MinWantsOnlyTheAlertAtTheDue() {
        #expect(wanted(alertPriority(due: "2026-10-12T10:30:00")) == [alert(.atDue, at: "2026-10-12T10:30:00")])
    }

    @Test
    func aDueIn30MinAndOneSecondWantsBoth() {
        #expect(wanted(alertPriority(due: "2026-10-12T10:30:01")) == [
            alert(.before30m, at: "2026-10-12T10:00:01"),
            alert(.atDue, at: "2026-10-12T10:30:01"),
        ])
    }

    @Test
    func aDueInOneSecondWantsTheAlertAtTheDue() {
        #expect(wanted(alertPriority(due: "2026-10-12T10:00:01")) == [alert(.atDue, at: "2026-10-12T10:00:01")])
    }

    @Test
    func aDueAtThisSecondWantsNone() {
        #expect(wanted(alertPriority(due: "2026-10-12T10:00:00")).isEmpty)
    }

    @Test
    func aDueInThePastWantsNone() {
        #expect(wanted(alertPriority(due: "2026-10-12T09:59:59")).isEmpty)
        #expect(wanted(alertPriority(due: "2026-10-11T12:00:00")).isEmpty)
    }

    @Test
    func aPriorityWithNoDueWantsNone() {
        #expect(wanted(alertPriority(due: nil)).isEmpty)
    }

    @Test
    func aDonePriorityWantsNone() {
        #expect(wanted(alertPriority(due: "2026-10-12T12:00:00", done: true)).isEmpty)
    }

    @Test
    func aDueChangeMovesBothAlerts() {
        var priority = alertPriority(due: "2026-10-12T12:00:00")
        priority.dueAt = localDate("2026-10-13T08:15:00")
        #expect(wanted(priority) == [
            alert(.before30m, at: "2026-10-13T07:45:00"),
            alert(.atDue, at: "2026-10-13T08:15:00"),
        ])
    }

    @Test
    func eachPriorityGetsItsOwnAlerts() {
        let result = wanted(
            alertPriority("p1", due: "2026-10-12T12:00:00"),
            alertPriority("p2", due: nil),
            alertPriority("p3", due: "2026-10-12T10:10:00")
        )
        #expect(result == [
            alert(.before30m, at: "2026-10-12T11:30:00", priority: "p1"),
            alert(.atDue, at: "2026-10-12T12:00:00", priority: "p1"),
            alert(.atDue, at: "2026-10-12T10:10:00", priority: "p3"),
        ])
    }
}

@Suite
struct AlertChangesTests {
    let now = localDate("2026-10-12T10:00:00")

    private func changes(
        _ priorities: [Priority],
        rows: [PriorityAlert],
        deliversAlerts: Bool = true
    ) -> AlertChanges {
        var count = 0
        return AlertPlanner.changes(open: priorities, rows: rows, now: now, deliversAlerts: deliversAlerts) {
            count += 1
            return "new-\(count)"
        }
    }

    private let planned = [
        alertRow("a1", .before30m, at: "2026-10-12T11:30:00"),
        alertRow("a2", .atDue, at: "2026-10-12T12:00:00"),
    ]

    @Test
    func aDueChangeMovesTheTwoRowsAndKeepsTheirIDs() {
        let result = changes([alertPriority(due: "2026-10-12T17:00:00")], rows: planned)
        let moved = [
            alertRow("a1", .before30m, at: "2026-10-12T16:30:00"),
            alertRow("a2", .atDue, at: "2026-10-12T17:00:00"),
        ]
        #expect(result.saved == moved)
        #expect(result.scheduled == moved)
        #expect(result.cancelled.isEmpty)
    }

    @Test
    func aPriorityThatIsNotOpenCancelsItsRows() {
        let result = changes([], rows: planned)
        #expect(result.saved.map(\.status) == [.cancelled, .cancelled])
        #expect(result.saved.map(\.id) == ["a1", "a2"])
        #expect(result.scheduled.isEmpty)
        #expect(result.cancelled == ["a1", "a2"])
    }

    @Test
    func aDonePriorityInTheListCancelsItsRows() {
        let result = changes([alertPriority(due: "2026-10-12T12:00:00", done: true)], rows: planned)
        #expect(result.cancelled == ["a1", "a2"])
        #expect(result.scheduled.isEmpty)
    }

    @Test
    func aDueThatIsRemovedCancelsTheRows() {
        let result = changes([alertPriority(due: nil)], rows: planned)
        #expect(result.cancelled == ["a1", "a2"])
        #expect(result.scheduled.isEmpty)
    }

    @Test
    func aDueThatMovesInside30MinCancelsTheRowBeforeAndMovesTheRowAtTheDue() {
        let result = changes([alertPriority(due: "2026-10-12T10:20:00")], rows: planned)
        var cancelled = planned[0]
        cancelled.status = .cancelled
        #expect(result.saved == [cancelled, alertRow("a2", .atDue, at: "2026-10-12T10:20:00")])
        #expect(result.scheduled.map(\.id) == ["a2"])
        #expect(result.cancelled == ["a1"])
    }

    @Test
    func aScheduledRowWithAPastFireTimeBecomesDelivered() {
        let rows = [
            alertRow("a1", .before30m, at: "2026-10-12T09:30:00"),
            alertRow("a2", .atDue, at: "2026-10-12T10:00:00"),
            alertRow("a3", .atDue, at: "2026-10-12T10:00:01", priority: "p2"),
        ]
        let result = changes(
            [alertPriority(due: "2026-10-12T10:00:00"), alertPriority("p2", due: "2026-10-12T10:00:01")],
            rows: rows
        )
        #expect(result.saved.map(\.id) == ["a1", "a2"])
        #expect(result.saved.map(\.status) == [.delivered, .delivered])
        #expect(result.scheduled.map(\.id) == ["a3"])
        #expect(result.cancelled.isEmpty)
    }

    @Test
    func withNoPermissionAPastRowBecomesCancelled() {
        let rows = [alertRow("a1", .before30m, at: "2026-10-12T09:30:00")]
        let result = changes([alertPriority(due: "2026-10-12T10:00:00")], rows: rows, deliversAlerts: false)
        #expect(result.saved.map(\.status) == [.cancelled])
        #expect(result.cancelled == ["a1"])
    }

    @Test
    func aDueThatMovesLaterAfterTheFirstAlertPlansANewAlertBefore() {
        let rows = [
            alertRow("a1", .before30m, at: "2026-10-12T09:45:00", status: .delivered),
            alertRow("a2", .atDue, at: "2026-10-12T10:15:00"),
        ]
        let result = changes([alertPriority(due: "2026-10-12T15:00:00")], rows: rows)
        #expect(result.saved == [
            alertRow("a2", .atDue, at: "2026-10-12T15:00:00"),
            alertRow("new-1", .before30m, at: "2026-10-12T14:30:00"),
        ])
        #expect(result.scheduled.map(\.id) == ["a2", "new-1"])
    }

    @Test
    func aSecondScheduledRowOfTheSameKindIsCancelled() {
        let rows = planned + [alertRow("a3", .atDue, at: "2026-10-12T12:00:00")]
        let result = changes([alertPriority(due: "2026-10-12T12:00:00")], rows: rows)
        #expect(result.saved.map(\.id) == ["a3"])
        #expect(result.cancelled == ["a3"])
        #expect(result.scheduled.map(\.id) == ["a1", "a2"])
    }

    @Test
    func aSnoozeStaysWhileItsPriorityIsOpenWithADue() {
        let snooze = alertRow("s1", .snooze, at: "2026-10-12T10:15:00")
        let result = changes([alertPriority(due: "2026-10-12T09:50:00")], rows: [snooze])
        #expect(result.saved.isEmpty)
        #expect(result.scheduled == [snooze])
        #expect(result.cancelled.isEmpty)
    }

    @Test
    func aSnoozeIsCancelledWhenItsPriorityIsDoneOrGoneOrHasNoDue() {
        let snooze = alertRow("s1", .snooze, at: "2026-10-12T10:15:00")
        #expect(changes([], rows: [snooze]).cancelled == ["s1"])
        #expect(changes([alertPriority(due: "2026-10-12T09:50:00", done: true)], rows: [snooze]).cancelled == ["s1"])
        #expect(changes([alertPriority(due: nil)], rows: [snooze]).cancelled == ["s1"])
    }

    @Test
    func aSnoozeWithAPastFireTimeBecomesDelivered() {
        let snooze = alertRow("s1", .snooze, at: "2026-10-12T10:00:00")
        let result = changes([alertPriority(due: "2026-10-12T09:50:00")], rows: [snooze])
        #expect(result.saved.map(\.status) == [.delivered])
        #expect(result.scheduled.isEmpty)
    }

    @Test
    func aSnoozeDoesNotTakeThePlaceOfAWantedAlert() {
        let snooze = alertRow("s1", .snooze, at: "2026-10-12T10:15:00")
        let result = changes([alertPriority(due: "2026-10-12T12:00:00")], rows: [snooze])
        #expect(result.saved.map(\.kind) == [.before30m, .atDue])
        #expect(result.scheduled.map(\.id) == ["s1", "new-1", "new-2"])
    }

    @Test
    func theChangesAppliedToTheRowsGiveNoChangeTheSecondTime() {
        let priorities = [alertPriority(due: "2026-10-12T17:00:00"), alertPriority("p2", due: "2026-10-12T10:10:00")]
        let rows = planned + [alertRow("a3", .atDue, at: "2026-10-12T09:00:00", priority: "p2")]
        let first = changes(priorities, rows: rows)
        var after = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        for row in first.saved {
            after[row.id] = row
        }
        let second = changes(priorities, rows: after.values.sorted { $0.id < $1.id })
        #expect(second.saved.isEmpty)
        #expect(second.cancelled.isEmpty)
        #expect(second.scheduled.map(\.id).sorted() == first.scheduled.map(\.id).sorted())
        #expect(second.scheduled.map(\.id).sorted() == ["a1", "a2", "new-1"])
    }

    @Test
    func aDueWithNoRowAddsTheTwoRows() {
        let result = changes([alertPriority(due: "2026-10-12T12:00:00")], rows: [])
        let expected = [
            alertRow("new-1", .before30m, at: "2026-10-12T11:30:00"),
            alertRow("new-2", .atDue, at: "2026-10-12T12:00:00"),
        ]
        #expect(result.saved == expected)
        #expect(result.scheduled == expected)
    }

    @Test
    func rowsThatMatchThePlanGiveNoChange() {
        let rows = [
            alertRow("a1", .before30m, at: "2026-10-12T11:30:00"),
            alertRow("a2", .atDue, at: "2026-10-12T12:00:00"),
        ]
        let result = changes([alertPriority(due: "2026-10-12T12:00:00")], rows: rows)
        #expect(result.saved.isEmpty)
        #expect(result.scheduled == rows)
    }

    @Test
    func onlyTheMissingKindIsAdded() {
        let rows = [alertRow("a2", .atDue, at: "2026-10-12T12:00:00")]
        let result = changes([alertPriority(due: "2026-10-12T12:00:00")], rows: rows)
        #expect(result.saved == [alertRow("new-1", .before30m, at: "2026-10-12T11:30:00")])
        #expect(result.scheduled.map(\.id) == ["a2", "new-1"])
    }

    @Test
    func aRowThatIsNotScheduledDoesNotCountAsPlanned() {
        let rows = [
            alertRow("a1", .before30m, at: "2026-10-12T11:30:00", status: .cancelled),
            alertRow("a2", .atDue, at: "2026-10-12T12:00:00", status: .delivered),
        ]
        let result = changes([alertPriority(due: "2026-10-12T12:00:00")], rows: rows)
        #expect(result.saved.map(\.id) == ["new-1", "new-2"])
        #expect(result.scheduled.map(\.id) == ["new-1", "new-2"])
    }
}
