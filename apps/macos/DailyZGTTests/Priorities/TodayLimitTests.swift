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

    @discardableResult
    private func fill(_ store: AppStore, open count: Int, list: PriorityList = .today) throws -> [Priority] {
        try (1...count).map { index in
            try store.addPriority(title: "Prioridad \(index)", level: .medium, list: list)
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
    func theMessageIsTheCopyOfThePlan() {
        #expect(TodayLimit.message == "Hoy ya tiene 5 prioridades abiertas.")
        #expect(SettingsCopy.todayLimitTitle == "Máximo 5 prioridades abiertas en Hoy")
    }

    @Test
    func theSettingIsOffByDefault() throws {
        let store = try makeStore(clock)
        #expect(!store.todayLimitIsOn)
        try fill(store, open: 5)
        #expect(store.canAddToToday())
        #expect(store.todayAddBlock() == nil)
    }

    @Test
    func theStoreAnswersWithFourFiveAndSixOpenPriorities() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        let first = try fill(store, open: 4)
        #expect(store.canAddToToday())
        #expect(store.todayAddBlock() == nil)

        try store.addPriority(title: "Quinta", list: .today)
        #expect(!store.canAddToToday())
        #expect(store.todayAddBlock() == "Hoy ya tiene 5 prioridades abiertas.")

        try store.markDone(first[0].id)
        #expect(store.canAddToToday())
        try store.restorePriority(first[0].id)
        try store.addPriority(title: "Sexta", list: .today)
        #expect(store.openCount(in: .today) == 6)
        #expect(!store.canAddToToday())
    }

    @Test
    func onlyOpenPrioritiesOfHoyCount() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        try fill(store, open: 5, list: .week)
        #expect(store.canAddToToday())
        let today = try fill(store, open: 4)
        for priority in today.prefix(2) {
            try store.markDone(priority.id)
        }
        try store.addPriority(title: "Otra", list: .today)
        #expect(store.openCount(in: .today) == 3)
        #expect(store.canAddToToday())
    }

    @Test
    func theFormInHoyDoesNotAddAtTheLimitAndKeepsTheText() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        try fill(store, open: 5)
        var form = NewPriorityForm()
        form.open()
        form.draft.title = "Una más"
        form.draft.level = .high
        form.draft.dueAt = localDate("2026-10-12T16:00:00")

        let added = try form.submit(to: store, list: .today)

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
    func theFormInHoyAddsWithFourOpenPriorities() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        try fill(store, open: 4)
        var form = NewPriorityForm()
        form.draft.title = "La quinta"
        let added = try form.submit(to: store, list: .today)
        #expect(added?.title == "La quinta")
        #expect(!form.isBlockedByLimit)
        #expect(store.openCount(in: .today) == 5)
    }

    @Test
    func theFormInSemanaIsNeverBlocked() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        try fill(store, open: 6)
        var form = NewPriorityForm()
        form.draft.title = "Para la semana"
        let added = try form.submit(to: store, list: .week)
        #expect(added?.list == .week)
        #expect(!form.isBlockedByLimit)
    }

    @Test
    func theFormAddsAfterTheLimitIsFreedAndClearsTheMark() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        let today = try fill(store, open: 5)
        var form = NewPriorityForm()
        form.draft.title = "Una más"
        try form.submit(to: store, list: .today)
        #expect(form.isBlockedByLimit)

        try store.markDone(today[0].id)
        let added = try form.submit(to: store, list: .today)

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
        #expect(try form.submit(to: store, list: .today) == nil)
        #expect(!form.isBlockedByLimit)
    }

    @Test
    func cancelClearsTheMark() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        try fill(store, open: 5)
        var form = NewPriorityForm()
        form.draft.title = "Una más"
        try form.submit(to: store, list: .today)
        form.cancel()
        #expect(form == NewPriorityForm())
    }

    @Test
    func theSettingOffAddsEvenWithFiveOpenPriorities() throws {
        let store = try makeStore(clock)
        try fill(store, open: 5)
        var form = NewPriorityForm()
        form.draft.title = "La sexta"
        let added = try form.submit(to: store, list: .today)
        #expect(added != nil)
        #expect(store.openCount(in: .today) == 6)
    }

    @Test
    func theMoveToHoyIsBlockedAtTheLimit() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        try fill(store, open: 5)
        let weekly = try store.addPriority(title: "De la semana", list: .week)
        let actions = PriorityDetailActions(store: store, id: weekly.id)

        let result = try actions.setList(.today)

        #expect(result == .blocked("Hoy ya tiene 5 prioridades abiertas."))
        #expect(store.priority(id: weekly.id)?.list == .week)
        #expect(try store.events(of: weekly.id).map(\.type) == [.created])
        #expect(store.openCount(in: .today) == 5)
    }

    @Test
    func theMoveToHoyWorksWithFourOpenPriorities() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        try fill(store, open: 4)
        let weekly = try store.addPriority(title: "De la semana", list: .week)
        let result = try PriorityDetailActions(store: store, id: weekly.id).setList(.today)
        #expect(result == .moved)
        #expect(store.priority(id: weekly.id)?.list == .today)
    }

    @Test
    func theMoveToSemanaIsNeverBlocked() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        let today = try fill(store, open: 6)
        let result = try PriorityDetailActions(store: store, id: today[0].id).setList(.week)
        #expect(result == .moved)
        #expect(store.priority(id: today[0].id)?.list == .week)
    }

    @Test
    func theMoveIsNotBlockedWhenTheSettingIsOff() throws {
        let store = try makeStore(clock)
        try fill(store, open: 5)
        let weekly = try store.addPriority(title: "De la semana", list: .week)
        let result = try PriorityDetailActions(store: store, id: weekly.id).setList(.today)
        #expect(result == .moved)
    }

    @Test
    func aMissingPriorityStillThrows() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        try fill(store, open: 5)
        #expect(throws: AppStoreError.priorityNotFound("missing")) {
            try PriorityDetailActions(store: store, id: "missing").setList(.today)
        }
    }

    @Test
    func undoGivesBackThePriorityAtTheLimit() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        let today = try fill(store, open: 5)
        let flow = PriorityFlow(store: store, schedule: recorder.schedule)
        flow.confirmDone(today[0].id)
        try store.addPriority(title: "Sexta", list: .today)
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
        try store.addPriority(title: "Sexta", list: .today)
        let flow = PriorityFlow(store: store, schedule: recorder.schedule)

        flow.restore(today[0].id)

        #expect(store.priority(id: today[0].id)?.isDone == false)
        #expect(store.openCount(in: .today) == 6)
    }

    @Test
    func theDailyCopyIsNotBlockedAtTheLimit() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        try addDaily(store, title: "Meditar")
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
        try form.submit(to: store, list: .today)
        #expect(form.isBlockedByLimit)
        try render(
            NewPriorityFormView(form: .constant(form), now: clock.date, limitNotice: store.todayAddBlock(), onSubmit: {}),
            named: "today-limit-form"
        )
    }

    @Test
    func rendersTheDetailBoxWithTheLimitLine() throws {
        let store = try makeStore(clock)
        try turnOn(store)
        try fill(store, open: 5)
        let weekly = try store.addPriority(title: "Preparar la demo del viernes", level: .low, list: .week)
        let box = PriorityDetailBox(
            priority: weekly,
            now: clock.date,
            listNotice: store.todayAddBlock(),
            onLevel: { _ in },
            onDue: { _ in },
            onList: { _ in }
        )
        try render(box, named: "today-limit-detail-box")
    }

    @Test
    func theDetailBoxIsTallerWithTheLine() throws {
        let store = try makeStore(clock)
        let weekly = try store.addPriority(title: "Preparar la demo", level: .low, list: .week)
        func height(_ notice: String?) -> CGFloat {
            let box = PriorityDetailBox(priority: weekly, now: clock.date, listNotice: notice, onLevel: { _ in }, onDue: { _ in }, onList: { _ in })
            return NSHostingView(rootView: box.frame(width: Theme.Panel.width - Theme.Panel.padding * 2)).fittingSize.height
        }
        #expect(height(TodayLimit.message) > height(nil))
    }
}
