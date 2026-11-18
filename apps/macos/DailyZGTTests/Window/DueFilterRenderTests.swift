import AppKit
import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct DueFilterRenderTests {
    let clock = TestClock("2026-11-17T10:24:00")

    private func sampleStore() throws -> AppStore {
        let store = try makeStore(clock)
        try store.addPriority(title: "Release notes v2", level: .high, dueAt: localDate("2026-11-16T09:00:00"))
        try store.addPriority(title: "Revisar el MR de compass.ui", level: .medium, dueAt: localDate("2026-11-17T09:00:00"))
        let brief = try store.addPriority(
            title: "Ventas: confirmacion de whatsapp integration (SMS, OTP)",
            level: .high,
            dueAt: localDate("2026-11-17T17:00:00"),
            note: "Crear los planes tecnicos."
        )
        let first = try store.addSubtask(to: brief.id, title: "Draft de la API")
        try store.addSubtask(to: brief.id, title: "Revisar con ventas")
        try store.toggleSubtask(first.id)
        try store.addPriority(title: "Gyro desktop app release", level: .medium, dueAt: localDate("2026-11-17T18:30:00"))
        try store.addPriority(title: "Preparar la demo", level: .medium, dueAt: localDate("2026-11-18T09:00:00"))
        try store.addPriority(title: "1:1 con el equipo", level: .low, dueAt: localDate("2026-11-19T16:00:00"))
        try store.addPriority(title: "Cerrar el sprint", level: .high, dueAt: localDate("2026-11-24T12:00:00"))
        try store.addPriority(title: "Leer RFC de alertas", level: .low)
        let done = try store.addPriority(title: "Mandar el reporte", level: .medium, dueAt: localDate("2026-11-17T08:00:00"))
        try store.markDone(done.id)
        return store
    }

    private func defaults() -> UserDefaults {
        let name = "due-filter-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func window(_ store: AppStore, _ state: PanelState, width: CGFloat, height: CGFloat) -> some View {
        MainWindowView(defaults: defaults())
            .environment(store)
            .environment(state)
            .frame(width: width, height: height)
    }

    private func panel(_ store: AppStore, _ state: PanelState) -> some View {
        PanelView().environment(store).environment(state).padding(Theme.Space.s3)
    }

    private func expectPNG(_ view: some View, named name: String) throws {
        let url = try Screenshot.writeHosted(view, named: name)
        #expect(try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) > 0)
    }

    private func state(_ store: AppStore, _ filter: DueFilter) -> PanelState {
        let state = PanelState(store: store)
        state.select(filter: filter)
        return state
    }

    @Test
    func rendersThePanelWithEachFilter() throws {
        let store = try sampleStore()
        let cases: [(DueFilter, String)] = [
            (.today, "today"),
            (.tomorrow, "tomorrow"),
            (.week, "week"),
            (.overdue, "overdue"),
            (.noDate, "nodate"),
            (.all, "all"),
            (.day("2026-11-19"), "day"),
            (.range("2026-11-17", "2026-11-24"), "range"),
        ]
        for (filter, name) in cases {
            try expectPNG(panel(store, state(store, filter)), named: "filter-panel-\(name)")
        }
    }

    @Test
    func rendersTheWindowWithTheFilterAt980And2000() throws {
        let store = try sampleStore()
        let today = state(store, .today)
        try expectPNG(window(store, today, width: 980, height: 680), named: "filter-window-980-today")
        let brief = try #require(store.openPriorities(in: .today).first { $0.title.hasPrefix("Ventas") })
        today.openDetail(brief.id)
        try expectPNG(window(store, today, width: 2000, height: 1200), named: "filter-window-2000-today-detail")
        try expectPNG(window(store, state(store, .all), width: 980, height: 680), named: "filter-window-980-all")
        try expectPNG(window(store, state(store, .tomorrow), width: 980, height: 680), named: "filter-window-980-tomorrow-link")
        try expectPNG(window(store, state(store, .range("2026-11-17", "2026-11-24")), width: 2000, height: 1200), named: "filter-window-2000-range")
    }

    @Test
    func rendersTheEmptyStateOfEachFilter() throws {
        let store = try makeStore(clock)
        let cases: [(DueFilter, String)] = [
            (.today, "today"),
            (.tomorrow, "tomorrow"),
            (.week, "week"),
            (.overdue, "overdue"),
            (.noDate, "nodate"),
            (.all, "all"),
            (.day("2026-11-19"), "day"),
            (.range("2026-11-17", "2026-11-24"), "range"),
        ]
        for (filter, name) in cases {
            try expectPNG(panel(store, state(store, filter)), named: "filter-empty-\(name)")
        }
        let done = try store.addPriority(title: "Hecha hoy")
        try store.markDone(done.id)
        try expectPNG(panel(store, state(store, .today)), named: "filter-empty-today-all-done")
        try expectPNG(window(store, state(store, .tomorrow), width: 980, height: 680), named: "filter-window-980-empty-tomorrow")
    }

    @Test
    func rendersTheOverdueLinkOnAnotherDay() throws {
        let store = try sampleStore()
        let state = state(store, .tomorrow)
        #expect(store.hiddenOverdueCount(in: .tomorrow) == 2)
        try expectPNG(panel(store, state), named: "filter-panel-tomorrow-link")
    }

    @Test
    func rendersTheFilterPopoverInDayAndRangeMode() throws {
        let store = try sampleStore()
        let days = store.dueDays
        let counts = Dictionary(uniqueKeysWithValues: DueFilter.quickOptions.map { ($0, store.openCount(in: $0)) })
        try expectPNG(
            DueFilterPopover(selection: .today, days: days, counts: counts, onSelect: { _ in }),
            named: "filter-popover-day"
        )
        try expectPNG(
            DueFilterPopover(selection: .range("2026-11-17", "2026-11-24"), days: days, counts: counts, onSelect: { _ in }),
            named: "filter-popover-range"
        )
    }

    @Test
    func theOverdueLinkSelectsVencidas() throws {
        let store = try sampleStore()
        let state = state(store, .tomorrow)
        state.select(filter: .overdue)
        #expect(state.filter == .overdue)
        #expect(store.openPriorities(in: .overdue).map(\.title) == ["Release notes v2", "Revisar el MR de compass.ui"])
    }

    @Test
    func aClickOnTheCalendarArrowIsNotADayPick() {
        let calendar = DueDays(now: clock.date).calendar
        #expect(CalendarClick.isMonthStep(from: localDate("2026-11-17T00:00:00"), to: localDate("2026-12-17T00:00:00"), calendar: calendar))
        #expect(CalendarClick.isMonthStep(from: localDate("2026-11-17T00:00:00"), to: localDate("2026-10-17T00:00:00"), calendar: calendar))
        #expect(CalendarClick.isMonthStep(from: localDate("2027-01-31T00:00:00"), to: localDate("2027-02-28T00:00:00"), calendar: calendar))
        #expect(CalendarClick.isMonthStep(from: localDate("2026-12-05T00:00:00"), to: localDate("2027-01-05T00:00:00"), calendar: calendar))
        #expect(!CalendarClick.isMonthStep(from: localDate("2026-11-17T00:00:00"), to: localDate("2026-11-19T00:00:00"), calendar: calendar))
        #expect(!CalendarClick.isMonthStep(from: localDate("2026-11-17T00:00:00"), to: localDate("2026-12-18T00:00:00"), calendar: calendar))
        #expect(!CalendarClick.isMonthStep(from: localDate("2026-11-17T00:00:00"), to: localDate("2027-11-17T00:00:00"), calendar: calendar))
    }
}
