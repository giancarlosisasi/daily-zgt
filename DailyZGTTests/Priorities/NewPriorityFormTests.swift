import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct NewPriorityFormTests {
    let clock = TestClock("2026-10-12T10:24:00")

    @Test
    func startsClosedWithMediumLevelAndNoDue() {
        let form = NewPriorityForm()
        #expect(!form.isOpen)
        #expect(form.draft.title == "")
        #expect(form.draft.level == .medium)
        #expect(form.draft.dueAt == nil)
        #expect(!form.draft.showsAlertHint)
    }

    @Test
    func theTitleIsTrimmed() throws {
        let store = try makeStore(clock)
        var form = NewPriorityForm()
        form.draft.title = "  \n Send the report \t "
        let added = try #require(try form.submit(to: store, list: .today))
        #expect(added.title == "Send the report")
        #expect(store.openPriorities(in: .today).map(\.title) == ["Send the report"])
    }

    @Test
    func anEmptyOrBlankTitleDoesNotAdd() throws {
        let store = try makeStore(clock)
        var form = NewPriorityForm()
        form.open()
        #expect(try form.submit(to: store, list: .today) == nil)
        form.draft.title = "   \n "
        #expect(!form.draft.canAdd)
        #expect(try form.submit(to: store, list: .today) == nil)
        #expect(store.openPriorities(in: .today).isEmpty)
        #expect(form.isOpen)
        #expect(form.draft.title == "   \n ")
    }

    @Test
    func theDefaultLevelIsMedium() throws {
        let store = try makeStore(clock)
        var form = NewPriorityForm()
        form.draft.title = "Read"
        let added = try #require(try form.submit(to: store, list: .today))
        #expect(added.level == .medium)
    }

    @Test
    func theChosenLevelIsUsed() throws {
        let store = try makeStore(clock)
        var form = NewPriorityForm()
        form.draft.title = "Urgent"
        form.draft.level = .high
        let added = try #require(try form.submit(to: store, list: .today))
        #expect(added.level == .high)
    }

    @Test
    func theDueDateIsOptional() throws {
        let store = try makeStore(clock)
        var form = NewPriorityForm()
        form.draft.title = "No due"
        let without = try #require(try form.submit(to: store, list: .today))
        #expect(without.dueAt == nil)

        let due = localDate("2026-10-12T16:00:00")
        form.draft.title = "With due"
        form.draft.dueAt = due
        #expect(form.draft.showsAlertHint)
        let with = try #require(try form.submit(to: store, list: .today))
        #expect(with.dueAt == due)
    }

    @Test
    func theNewPriorityGoesToTheOpenList() throws {
        let store = try makeStore(clock)
        var form = NewPriorityForm()
        form.draft.title = "For the week"
        try form.submit(to: store, list: .week)
        form.draft.title = "For today"
        try form.submit(to: store, list: .today)
        #expect(store.openPriorities(in: .week).map(\.title) == ["For the week"])
        #expect(store.openPriorities(in: .today).map(\.title) == ["For today"])
    }

    @Test
    func theNewRowTakesItsSortedPlace() throws {
        let store = try makeStore(clock)
        try store.addPriority(title: "medium", level: .medium, list: .today)
        try store.addPriority(title: "low", level: .low, list: .today)
        var form = NewPriorityForm()
        form.draft.title = "high"
        form.draft.level = .high
        try form.submit(to: store, list: .today)
        #expect(store.openPriorities(in: .today).map(\.title) == ["high", "medium", "low"])
    }

    @Test
    func aSuccessfulAddClosesAndResetsTheForm() throws {
        let store = try makeStore(clock)
        var form = NewPriorityForm()
        form.open()
        form.draft.title = "Done"
        form.draft.level = .low
        form.draft.dueAt = localDate("2026-10-12T16:00:00")
        try form.submit(to: store, list: .today)
        #expect(form == NewPriorityForm())
    }

    @Test
    func cancelClosesAndResetsTheDraft() {
        var form = NewPriorityForm()
        form.open()
        form.draft.title = "Draft"
        form.draft.level = .high
        form.cancel()
        #expect(form == NewPriorityForm())
    }

    @Test
    func closeKeepsTheDraft() {
        var form = NewPriorityForm()
        form.open()
        form.draft.title = "Draft"
        form.close()
        #expect(!form.isOpen)
        #expect(form.draft.title == "Draft")
        form.open()
        #expect(form.draft.title == "Draft")
    }

    @Test
    func theDefaultDueIsTheNextWholeHour() {
        #expect(NewPriorityDraft.defaultDue(after: localDate("2026-10-12T10:24:00")) == localDate("2026-10-12T11:00:00"))
        #expect(NewPriorityDraft.defaultDue(after: localDate("2026-10-12T10:00:00")) == localDate("2026-10-12T11:00:00"))
        #expect(NewPriorityDraft.defaultDue(after: localDate("2026-10-12T23:30:00")) == localDate("2026-10-13T00:00:00"))
    }

    private func render(_ view: some View, named name: String) throws {
        let url = try Screenshot.writeHosted(view.panelChrome(), named: name)
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func rendersTheNewPriorityButton() throws {
        try render(NewPriorityButton {}, named: "priorities-new-button")
    }

    @Test
    func rendersTheEmptyForm() throws {
        var form = NewPriorityForm()
        form.open()
        try render(NewPriorityFormView(form: .constant(form), now: clock.date, onSubmit: {}), named: "priorities-form-empty")
    }

    @Test
    func rendersTheEmptyFormWithTheFocusRing() throws {
        var form = NewPriorityForm()
        form.open()
        try render(
            NewPriorityFormView(form: .constant(form), now: clock.date, showsTitleFocus: true, onSubmit: {}),
            named: "priorities-form-focus"
        )
    }

    @Test
    func rendersTheFilledForm() throws {
        var form = NewPriorityForm()
        form.open()
        form.draft.title = "Enviar el reporte de QA"
        form.draft.level = .high
        form.draft.dueAt = localDate("2026-10-12T16:00:00")
        try render(NewPriorityFormView(form: .constant(form), now: clock.date, onSubmit: {}), named: "priorities-form-filled")
    }

    @Test
    func rendersTheListWithTheOpenForm() throws {
        let store = try makeStore(clock)
        try store.addPriority(title: "Una prioridad", level: .high, list: .today)
        let state = PanelState(store: store)
        try render(PanelView().environment(store).environment(state), named: "priorities-panel-new-button")
    }
}
