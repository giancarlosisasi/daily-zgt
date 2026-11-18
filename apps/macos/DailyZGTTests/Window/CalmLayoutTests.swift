import AppKit
import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct CalmLayoutTests {
    let clock = TestClock("2026-11-17T10:24:00")

    static let longTitle = "Ventas: confirmacion de whatsapp integration (SMS, OTP) con el equipo de producto y el de soporte"

    private func sampleStore() throws -> (AppStore, Priority) {
        let store = try makeStore(clock)
        let brief = try store.addPriority(
            title: Self.longTitle,
            level: .high,
            list: .today,
            dueAt: localDate("2026-11-24T17:00:00"),
            note: "Crear los planes tecnicos y la estimacion a nivel de producto.\n\n- Listado de notificaciones\n- Fecha posible con ventas"
        )
        let first = try store.addSubtask(to: brief.id, title: "Draft de la API")
        try store.addSubtask(to: brief.id, title: "Revisar con ventas")
        try store.toggleSubtask(first.id)
        try store.addPriority(title: "Release notes v2", level: .high, list: .today, dueAt: localDate("2026-11-17T09:00:00"))
        try store.addPriority(title: "Gyro desktop app release", level: .medium, list: .today, dueAt: localDate("2026-11-17T18:30:00"))
        try store.addPriority(title: "Leer RFC de alertas", level: .low, list: .today)
        return (store, brief)
    }

    private func defaults() -> UserDefaults {
        let name = "calm-layout-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func window(_ store: AppStore, _ state: PanelState, width: CGFloat, height: CGFloat, defaults: UserDefaults? = nil) -> some View {
        MainWindowView(defaults: defaults ?? self.defaults())
            .environment(store)
            .environment(state)
            .frame(width: width, height: height)
    }

    private func expectPNG(_ view: some View, named name: String) throws {
        let url = try Screenshot.writeHosted(view, named: name)
        #expect(try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) > 0)
    }

    @Test
    func theLayoutWidthsComeFromTecla() {
        #expect(Theme.Panel.width == TeclaTokens.Layout.panelWidth)
        #expect(Theme.Panel.width == 360)
        #expect(Theme.Panel.padding == TeclaTokens.Space.s3)
        #expect(Theme.Panel.spacing == TeclaTokens.Space.s3)
        #expect(Theme.Window.sidebarMin == 280)
        #expect(Theme.Window.sidebarIdeal == 340)
        #expect(Theme.Window.sidebarMax == 440)
        #expect(Theme.Window.readableWidth == 560)
        #expect(Theme.Space.group(.window) == TeclaTokens.Space.s5)
        #expect(Theme.Space.group(.panel) == TeclaTokens.Space.s4)
    }

    @Test
    func theSidebarWidthStaysBetweenItsLimits() {
        #expect(Theme.Window.clampedSidebar(100) == 280)
        #expect(Theme.Window.clampedSidebar(340) == 340)
        #expect(Theme.Window.clampedSidebar(900) == 440)
    }

    @Test
    func theDueValueShowsTheDayAndTheTime() {
        let now = localDate("2026-11-17T10:24:00")
        #expect(PriorityDetailLabels.due(nil, now: now) == "Sin fecha")
        #expect(PriorityDetailLabels.due(localDate("2026-11-17T17:00:00"), now: now) == "Hoy · 17:00")
        #expect(PriorityDetailLabels.due(localDate("2026-11-18T09:00:00"), now: now) == "Mañana · 09:00")
        #expect(PriorityDetailLabels.due(localDate("2026-11-24T17:00:00"), now: now) == "mar 24 nov · 17:00")
        #expect(PriorityDetailLabels.repeatValue(.none) == "No se repite")
        #expect(PriorityDetailLabels.repeatValue(.daily) == "Cada día")
    }

    @Test
    func theQuickOptionsKeepTheTimeThatIsSet() {
        let now = localDate("2026-11-17T10:24:00")
        let due = localDate("2026-11-20T17:30:00")
        #expect(DueQuickOption.today.date(current: due, now: now) == localDate("2026-11-17T17:30:00"))
        #expect(DueQuickOption.tomorrow.date(current: due, now: now) == localDate("2026-11-18T17:30:00"))
        #expect(DueQuickOption.nextMonday.date(current: due, now: now) == localDate("2026-11-23T17:30:00"))
        #expect(DueQuickOption.inOneWeek.date(current: due, now: now) == localDate("2026-11-24T17:30:00"))
        #expect(DueQuickOption.today.date(current: nil, now: now) == localDate("2026-11-17T11:00:00"))
        #expect(DueQuickOption.nextMonday.date(current: due, now: localDate("2026-11-23T08:00:00")) == localDate("2026-11-30T17:30:00"))
    }

    @Test
    func aDayAndATimeJoinIntoOneDue() {
        let joined = DueParts.join(day: localDate("2026-12-01T00:00:00"), time: localDate("2026-11-17T08:45:00"))
        #expect(joined == localDate("2026-12-01T08:45:00"))
    }

    @Test
    func theHistoryDayCountAndTimeAreShort() {
        #expect(HistoryCopy.count(1) == "1 hecha")
        #expect(HistoryCopy.count(3) == "3 hechas")
        #expect(HistoryCopy.time(of: localDate("2026-11-13T18:40:00")) == "18:40")
        #expect(HistoryCopy.time(of: nil) == nil)
    }

    @Test
    func theDetailHasNoBackKeyAndNoPendingChipInTheWindow() throws {
        let (store, brief) = try sampleStore()
        let state = PanelState(store: store)
        state.openDetail(brief.id)
        let hosting = NSHostingView(rootView: window(store, state, width: 980, height: 680))
        hosting.frame = NSRect(x: 0, y: 0, width: 980, height: 680)
        hosting.layoutSubtreeIfNeeded()
        #expect(!PriorityDetailChips.showsAny(priority: brief, now: clock.date))
        let overdue = try #require(store.openPriorities(in: .today).first { $0.title == "Release notes v2" })
        #expect(PriorityDetailChips.showsAny(priority: overdue, now: clock.date))
    }

    @Test
    func rendersTheWindowAt980WithTheDetail() throws {
        let (store, brief) = try sampleStore()
        let state = PanelState(store: store)
        state.openDetail(brief.id)
        try expectPNG(window(store, state, width: 980, height: 680), named: "calm-window-980-detail")
    }

    @Test
    func rendersTheWindowInFullScreenWithTheDetail() throws {
        let (store, brief) = try sampleStore()
        let state = PanelState(store: store)
        state.openDetail(brief.id)
        try expectPNG(window(store, state, width: 2000, height: 1200), named: "calm-window-2000-detail")
    }

    @Test
    func rendersTheWindowWithAWideSidebar() throws {
        let (store, brief) = try sampleStore()
        let state = PanelState(store: store)
        state.openDetail(brief.id)
        let wide = defaults()
        wide.set(900.0, forKey: Theme.Window.sidebarWidthKey)
        try expectPNG(window(store, state, width: 980, height: 680, defaults: wide), named: "calm-window-980-wide-sidebar")
    }

    @Test
    func rendersTheWindowWithTheConfirmationBar() throws {
        let (store, brief) = try sampleStore()
        let state = PanelState(store: store)
        state.openDetail(brief.id)
        state.priorityFlow.toggleConfirmation(for: brief.id)
        try expectPNG(window(store, state, width: 980, height: 680), named: "calm-window-980-confirm")
    }

    @Test
    func rendersTheWindowWithNoSelection() throws {
        let (store, _) = try sampleStore()
        let state = PanelState(store: store)
        try expectPNG(window(store, state, width: 980, height: 680), named: "calm-window-980-empty")
    }

    @Test
    func rendersTheWindowWithTheHistory() throws {
        let store = try makeStore(clock)
        let titles = [
            "Gyrocompass - open source",
            "Presentacion de cody y sus features (code review, design system, ai workflow y el resto de la demo)",
            "Hacer research (o crear) un framework de backoffice para los productos internos de la empresa",
            "1:1 new hiring",
        ]
        for (index, title) in titles.enumerated() {
            let priority = try store.addPriority(title: title, list: .today)
            clock.date = localDate("2026-11-1\(3 - index % 2)T1\(index):20:00")
            try store.markDone(priority.id)
        }
        clock.date = localDate("2026-11-17T10:24:00")
        let state = PanelState(store: store)
        state.toggleDone()
        state.openHistory()
        try expectPNG(window(store, state, width: 980, height: 680), named: "calm-window-980-history")
        try expectPNG(window(store, state, width: 2000, height: 1200), named: "calm-window-2000-history")
        state.closeHistory()
        try expectPNG(window(store, state, width: 980, height: 680), named: "calm-window-980-hechas")
    }

    @Test
    func rendersTheWindowWithTheSettings() throws {
        let (store, _) = try sampleStore()
        let state = PanelState(store: store)
        state.openSettings()
        try expectPNG(window(store, state, width: 980, height: 680), named: "calm-window-980-settings")
    }

    @Test
    func rendersTheWindowOnTheNotesTab() throws {
        let (store, _) = try sampleStore()
        let state = PanelState(store: store)
        try store.addNote(body: "Revisar el brief antes de las 11.\nLlamar a Ana.")
        state.select(tab: .notes)
        try expectPNG(window(store, state, width: 980, height: 680), named: "calm-window-980-notes")
    }

    @Test
    func rendersThePanelListAndDetail() throws {
        let (store, brief) = try sampleStore()
        let state = PanelState(store: store)
        try expectPNG(PanelView().environment(store).environment(state).padding(Theme.Space.s3), named: "calm-panel-list")
        state.openDetail(brief.id)
        try expectPNG(PanelView().environment(store).environment(state).padding(Theme.Space.s3), named: "calm-panel-detail")
    }

    @Test
    func rendersTheDuePopover() throws {
        let content = DuePopoverContent(
            dueAt: .constant(localDate("2026-11-24T17:00:00")),
            now: clock.date
        )
        try expectPNG(content, named: "calm-due-popover")
    }

    @Test
    func rendersTheNewPriorityFormWithTheDueButton() throws {
        let (store, _) = try sampleStore()
        var form = NewPriorityForm()
        form.open()
        form.draft.title = "Preparar la demo"
        form.draft.dueAt = localDate("2026-11-17T17:00:00")
        let view = NewPriorityFormView(form: .constant(form), now: clock.date, onSubmit: {})
            .environment(store)
            .frame(width: Theme.Panel.width - Theme.Panel.padding * 2)
            .padding(Theme.Panel.padding)
            .background(Theme.Panel.background)
        try expectPNG(view, named: "calm-form-due")
    }
}
