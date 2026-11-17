import AppKit
import Foundation
import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct TodayLimitTests {
    let clock = TestClock("2026-10-12T10:24:00")
    let recorder = ScheduleRecorder()
    static let todayDue = localDate("2026-10-12T18:00:00")
    static let tomorrowDue = localDate("2026-10-13T18:00:00")

    @discardableResult
    private func fill(_ store: AppStore, open count: Int, due: Date? = TodayLimitTests.todayDue) throws -> [Priority] {
        try (1...count).map { index in
            try store.addPriority(title: "Prioridad \(index)", level: .medium, dueAt: due)
        }
    }

    private func turnOn(_ store: AppStore) throws {
        try store.setValue(true, for: TodayLimit.key)
    }

    private func render(_ view: some View, named name: String) throws {
        let url = try Screenshot.writeHosted(view.panelChrome(), named: name)
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func theRuleBlocksOnlyWhenTheSettingIsOnAndTheCountIsFiveOrMore() {
        #expect(!TodayLimit.blocksAdd(isOn: false, openCount: 5))
        #expect(!TodayLimit.blocksAdd(isOn: false, openCount: 6))
        #expect(!TodayLimit.blocksAdd(isOn: true, openCount: 0))
        #expect(!TodayLimit.blocksAdd(isOn: true, openCount: 4))
        #expect(TodayLimit.blocksAdd(isOn: true, openCount: 5))
        #expect(TodayLimit.blocksAdd(isOn: true, openCount: 6))
    }

    @Test
    func noDueOrADueOfTodayOrBeforeLandsInHoy() {
        let days = DueDays(now: clock.date)
        #expect(TodayLimit.landsInToday(due: Self.todayDue, days))
        #expect(TodayLimit.landsInToday(due: localDate("2026-10-01T09:00:00"), days))
        #expect(TodayLimit.landsInToday(due: nil, days))
        #expect(!TodayLimit.landsInToday(due: Self.tomorrowDue, days))
    }

    @Test
    func theMessageIsTheCopyOfThePlan() {
        #expect(TodayLimit.message == "Hoy ya tiene 5 prioridades abiertas.")
        #expect(SettingsCopy.todayLimitTitle == "Máximo 5 prioridades abiertas en Hoy")
    }

    @Test
    func theSettingIsOffByDefault() throws {
        let store = try makeStore(clock)
        #expect(!store.todayLimitIsOn)
        try fill(store, open: 5)
        #expect(store.addBlock(forDue: Self.todayDue) == nil)
    }

    @Test
    func theStoreAnswersWithFourFiveAndSixOpenPriorities() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        let first = try fill(store, open: 4)
        #expect(store.addBlock(forDue: Self.todayDue) == nil)

        try store.addPriority(title: "Quinta", dueAt: Self.todayDue)
        #expect(store.addBlock(forDue: Self.todayDue) == "Hoy ya tiene 5 prioridades abiertas.")

        try store.markDone(first[0].id)
        #expect(store.addBlock(forDue: Self.todayDue) == nil)
        try store.restorePriority(first[0].id)
        try store.addPriority(title: "Sexta", dueAt: Self.todayDue)
        #expect(store.openCount(in: .today) == 6)
        #expect(store.addBlock(forDue: Self.todayDue) != nil)
    }

    @Test
    func onlyOpenPrioritiesDueTodayOrOverdueCount() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        try fill(store, open: 5, due: Self.tomorrowDue)
        try fill(store, open: 5, due: nil)
        #expect(store.openCount(in: .today) == 0)
        #expect(store.addBlock(forDue: Self.todayDue) == nil)
        let today = try fill(store, open: 4)
        for priority in today.prefix(2) {
            try store.markDone(priority.id)
        }
        try store.addPriority(title: "Vencida", dueAt: localDate("2026-10-10T09:00:00"))
        #expect(store.openCount(in: .today) == 3)
        #expect(store.addBlock(forDue: Self.todayDue) == nil)
    }

    @Test
    func onlyANewPriorityThatLandsInHoyIsBlocked() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        try fill(store, open: 6)
        #expect(store.addBlock(forDue: Self.tomorrowDue) == nil)
        #expect(store.addBlock(forDue: Self.todayDue) == TodayLimit.message)
        #expect(store.addBlock(forDue: nil) == TodayLimit.message)
    }

    @Test
    func theFormDoesNotAddADueOfTodayAtTheLimitAndKeepsTheText() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        try fill(store, open: 5)
        var form = NewPriorityForm()
        form.open()
        form.draft.title = "Una más"
        form.draft.level = .high
        form.draft.dueAt = localDate("2026-10-12T16:00:00")

        let added = try form.submit(to: store)

        #expect(added == nil)
        #expect(form.isBlockedByLimit)
        #expect(form.isOpen)
        #expect(form.draft.title == "Una más")
        #expect(form.draft.level == .high)
        #expect(form.draft.dueAt == localDate("2026-10-12T16:00:00"))
        #expect(store.openCount(in: .today) == 5)
        #expect(try values("SELECT COUNT(*) FROM priority", in: store.database, as: Int.self) == [5])
    }

    @Test
    func theFormAddsWithFourOpenPriorities() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        try fill(store, open: 4)
        var form = NewPriorityForm()
        form.draft.title = "La quinta"
        form.draft.dueAt = Self.todayDue
        let added = try form.submit(to: store)
        #expect(added?.title == "La quinta")
        #expect(!form.isBlockedByLimit)
        #expect(store.openCount(in: .today) == 5)
    }

    @Test
    func theFormWithADueOfAnotherDayIsNeverBlocked() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        try fill(store, open: 6)
        var form = NewPriorityForm()
        form.draft.title = "Para mañana"
        form.draft.dueAt = Self.tomorrowDue
        #expect(try form.submit(to: store)?.dueAt == Self.tomorrowDue)
        #expect(!form.isBlockedByLimit)
        form.draft.title = "Sin fecha"
        #expect(try form.submit(to: store) == nil)
        #expect(form.isBlockedByLimit)
    }

    @Test
    func theNewPriorityTakesTheDayOfTheFilterWhenTheFormOpens() {
        var form = NewPriorityForm()
        form.open(defaultDue: Self.tomorrowDue)
        #expect(form.draft.dueAt == Self.tomorrowDue)
        form.close()
        form.draft.title = "Escrito"
        form.open(defaultDue: Self.todayDue)
        #expect(form.draft.dueAt == Self.tomorrowDue)
        form.cancel()
        form.open(defaultDue: nil)
        #expect(form.draft.dueAt == nil)
    }

    @Test
    func theFormAddsAfterTheLimitIsFreedAndClearsTheMark() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        let today = try fill(store, open: 5)
        var form = NewPriorityForm()
        form.draft.title = "Una más"
        form.draft.dueAt = Self.todayDue
        try form.submit(to: store)
        #expect(form.isBlockedByLimit)

        try store.markDone(today[0].id)
        let added = try form.submit(to: store)

        #expect(added?.title == "Una más")
        #expect(form == NewPriorityForm())
    }

    @Test
    func aBlankTitleAtTheLimitShowsNoLine() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        try fill(store, open: 5)
        var form = NewPriorityForm()
        form.draft.title = "   "
        form.draft.dueAt = Self.todayDue
        #expect(try form.submit(to: store) == nil)
        #expect(!form.isBlockedByLimit)
    }

    @Test
    func cancelClearsTheMark() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        try fill(store, open: 5)
        var form = NewPriorityForm()
        form.draft.title = "Una más"
        form.draft.dueAt = Self.todayDue
        try form.submit(to: store)
        form.cancel()
        #expect(form == NewPriorityForm())
    }

    @Test
    func theSettingOffAddsEvenWithFiveOpenPriorities() throws {
        let store = try makeStore(clock)
        try fill(store, open: 5)
        var form = NewPriorityForm()
        form.draft.title = "La sexta"
        form.draft.dueAt = Self.todayDue
        let added = try form.submit(to: store)
        #expect(added != nil)
        #expect(store.openCount(in: .today) == 6)
    }

    @Test
    func aDueMoveIntoHoyIsBlockedAtTheLimit() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        try fill(store, open: 5)
        let later = try store.addPriority(title: "De la semana", dueAt: Self.tomorrowDue)
        let actions = PriorityDetailActions(store: store, id: later.id)

        let result = try actions.setDue(Self.todayDue)

        #expect(result == .blocked("Hoy ya tiene 5 prioridades abiertas."))
        #expect(store.priority(id: later.id)?.dueAt == Self.tomorrowDue)
        #expect(try store.events(of: later.id).map(\.type) == [.created])
        #expect(store.openCount(in: .today) == 5)
    }

    @Test
    func aDueMoveIntoHoyWorksWithFourOpenPriorities() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        try fill(store, open: 4)
        let later = try store.addPriority(title: "De la semana", dueAt: Self.tomorrowDue)
        let result = try PriorityDetailActions(store: store, id: later.id).setDue(Self.todayDue)
        #expect(result == .saved)
        #expect(store.priority(id: later.id)?.dueAt == Self.todayDue)
    }

    @Test
    func aDueMoveOutOfHoyIsNeverBlocked() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        let today = try fill(store, open: 6)
        let result = try PriorityDetailActions(store: store, id: today[0].id).setDue(Self.tomorrowDue)
        #expect(result == .saved)
        #expect(store.priority(id: today[0].id)?.dueAt == Self.tomorrowDue)
        let later = try store.addPriority(title: "Mañana", dueAt: Self.tomorrowDue)
        try store.addPriority(title: "Llena Hoy", dueAt: Self.todayDue)
        #expect(try PriorityDetailActions(store: store, id: later.id).setDue(nil) == .saved)
    }

    @Test
    func aDueMoveIsNotBlockedWhenTheSettingIsOff() throws {
        let store = try makeStore(clock)
        try fill(store, open: 5)
        let later = try store.addPriority(title: "De la semana", dueAt: Self.tomorrowDue)
        let result = try PriorityDetailActions(store: store, id: later.id).setDue(Self.todayDue)
        #expect(result == .saved)
    }

    @Test
    func aMissingPriorityStillThrows() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        try fill(store, open: 5)
        #expect(throws: AppStoreError.priorityNotFound("missing")) {
            try PriorityDetailActions(store: store, id: "missing").setDue(Self.tomorrowDue)
        }
    }

    @Test
    func undoGivesBackThePriorityAtTheLimit() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        let today = try fill(store, open: 5)
        let flow = PriorityFlow(store: store, schedule: recorder.schedule)
        flow.confirmDone(today[0].id)
        try store.addPriority(title: "Sexta", dueAt: Self.todayDue)
        #expect(store.openCount(in: .today) == 5)

        flow.undoDone()

        #expect(store.priority(id: today[0].id)?.isDone == false)
        #expect(store.openCount(in: .today) == 6)
        #expect(!flow.writeFailed)
    }

    @Test
    func regresarGivesBackThePriorityAtTheLimit() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        let today = try fill(store, open: 5)
        try store.markDone(today[0].id)
        try store.addPriority(title: "Sexta", dueAt: Self.todayDue)
        let flow = PriorityFlow(store: store, schedule: recorder.schedule)

        flow.restore(today[0].id)

        #expect(store.priority(id: today[0].id)?.isDone == false)
        #expect(store.openCount(in: .today) == 6)
    }

    @Test
    func theDailyCopyIsNotBlockedAtTheLimit() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        try addDaily(store, title: "Meditar", due: "2026-10-12T08:00:00")
        let daily = try #require(store.openPriorities(in: .today).first)
        try store.markDone(daily.id)
        try fill(store, open: 5)
        clock.date = localDate("2026-10-13T07:00:00")

        let added = try store.addRepeatCopies()

        #expect(added.map(\.title) == ["Meditar"])
        #expect(store.openCount(in: .today) == 6)
    }

    @Test
    func theSettingIsSavedInAppState() throws {
        let store = try makeStore(clock)
        let state = PanelState(store: store)
        state.setTodayLimit(true)
        #expect(store.todayLimitIsOn)
        #expect(try values("SELECT value FROM app_state WHERE key = 'today_limit'", in: store.database) == ["true"])
        state.setTodayLimit(false)
        #expect(!store.todayLimitIsOn)
        #expect(try values("SELECT value FROM app_state WHERE key = 'today_limit'", in: store.database) == ["false"])
        #expect(state.saveError == nil)
    }

    @Test
    func theSettingSurvivesAFileReopen() throws {
        let url = try temporaryFolder("today-limit").appending(path: "daily-zgt.sqlite")
        let first = AppStore(database: try AppDatabase.onDisk(at: url))
        PanelState(store: first).setTodayLimit(true)
        let second = AppStore(database: try AppDatabase.onDisk(at: url))
        #expect(second.todayLimitIsOn)
    }

    @Test
    func rendersTheSettingsRowOff() throws {
        let store = try makeStore(clock)
        try fill(store, open: 3)
        let state = PanelState(store: store)
        state.openSettings()
        let url = try Screenshot.writeHosted(PanelView().environment(store).environment(state), named: "today-limit-settings-off")
        #expect(try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) > 0)
    }

    @Test
    func rendersTheSettingsRowOn() throws {
        let store = try makeStore(clock)
        try fill(store, open: 3)
        let state = PanelState(store: store)
        state.setTodayLimit(true)
        state.openSettings()
        let url = try Screenshot.writeHosted(PanelView().environment(store).environment(state), named: "today-limit-settings-on")
        #expect(try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) > 0)
    }

    @Test
    func theSettingsRowTitleStaysOnOneLine() throws {
        func height(_ title: String) -> CGFloat {
            let row = SettingsRow(title: title, detail: SettingsCopy.todayLimitDetail) {
                SettingsToggle(title: title, isOn: false) { _ in }
            }
            return NSHostingView(rootView: row.frame(width: Theme.Panel.width - Theme.Panel.padding * 2)).fittingSize.height
        }
        #expect(height(SettingsCopy.todayLimitTitle) == height("Máximo"))
    }

    @Test
    func rendersTheFormWithTheLimitLine() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        try fill(store, open: 5)
        var form = NewPriorityForm()
        form.open()
        form.draft.title = "Llamar al banco"
        form.draft.level = .high
        form.draft.dueAt = Self.todayDue
        try form.submit(to: store)
        #expect(form.isBlockedByLimit)
        try render(
            NewPriorityFormView(form: .constant(form), now: clock.date, limitNotice: store.addBlock(forDue: Self.todayDue), onSubmit: {}),
            named: "today-limit-form"
        )
    }

    @Test
    func rendersTheDetailBoxWithTheLimitLine() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        try fill(store, open: 5)
        let weekly = try store.addPriority(title: "Preparar la demo del viernes", level: .low, dueAt: Self.tomorrowDue)
        let box = PriorityDetailBox(
            priority: weekly,
            now: clock.date,
            dueNotice: store.addBlock(forDue: Self.todayDue),
            onLevel: { _ in },
            onDue: { _ in }
        )
        try render(box, named: "today-limit-detail-box")
    }

    @Test
    func theDetailBoxIsTallerWithTheLine() throws {
        let store = try makeStore(clock)
        let weekly = try store.addPriority(title: "Preparar la demo", level: .low, dueAt: Self.tomorrowDue)
        func height(_ notice: String?) -> CGFloat {
            let box = PriorityDetailBox(priority: weekly, now: clock.date, dueNotice: notice, onLevel: { _ in }, onDue: { _ in })
            return NSHostingView(rootView: box.frame(width: Theme.Panel.width - Theme.Panel.padding * 2)).fittingSize.height
        }
        #expect(height(TodayLimit.message) > height(nil))
    }
}
