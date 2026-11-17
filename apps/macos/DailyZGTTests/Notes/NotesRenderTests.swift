import AppKit
import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct NotesRenderTests {
    let clock = TestClock("2026-11-17T16:40:00")

    static func richBody(image: String) -> String {
        """
        # Reunión con ventas
        Confirmar la fecha de **OTP** con el equipo de _ventas_ y el [ticket](https://zgt.dev).

        ## Pendientes
        - Listado de notificaciones
        - Fecha posible con ventas
        - [ ] Mandar el resumen

        ![](zgt-image:\(image))

        > Lo importante es la fecha de OTP.
        """
    }

    private func sampleStore() throws -> (AppStore, NoteItem) {
        let store = try makeStore(clock)
        let image = try store.images.insert(
            try #require(NoteImageEncoder.encode(TestImages.png(width: 1200, height: 420, alpha: true))),
            now: clock.date
        )
        clock.date = localDate("2026-11-10T09:00:00")
        try store.addNote(body: "Notas viejas de la semana pasada")
        clock.date = localDate("2026-11-16T11:15:00")
        try store.addNote(body: "## Retro del sprint\nQué salió bien: la demo.\n- Más tests")
        clock.date = localDate("2026-11-17T09:05:00")
        try store.addNote(body: "Llamar a Ana\nPreguntar por el brief de Tailwind v4 y la fecha de entrega")
        clock.date = localDate("2026-11-17T16:20:00")
        let rich = try store.addNote(body: Self.richBody(image: image))
        clock.date = localDate("2026-11-17T16:40:00")
        return (store, rich)
    }

    private func defaults() -> UserDefaults {
        let name = "notes-render-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func notesState(_ store: AppStore, _ filter: DueFilter = .today) -> PanelState {
        let state = PanelState(store: store)
        state.select(tab: .notes)
        state.select(noteFilter: filter)
        return state
    }

    private func expectPNG(_ view: some View, named name: String) throws {
        let url = try Screenshot.writeHosted(view, named: name)
        #expect(try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) > 0)
    }

    private func window(_ store: AppStore, _ state: PanelState, width: CGFloat, height: CGFloat, named name: String) async throws {
        let view = MainWindowView(defaults: defaults())
            .environment(store)
            .environment(state)
            .frame(width: width, height: height)
        let harness = RichNoteHarness(view, size: NSSize(width: width, height: height))
        defer { harness.close() }
        await RichNoteHarness.settle(400)
        let url = try harness.screenshot(named: name)
        #expect(try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) > 0)
    }

    @Test
    func rendersThePanelList() throws {
        let (store, _) = try sampleStore()
        try expectPNG(PanelView().environment(store).environment(notesState(store)).padding(Theme.Space.s3), named: "notes-panel-list")
        try expectPNG(PanelView().environment(store).environment(notesState(store, .week)).padding(Theme.Space.s3), named: "notes-panel-week")
        try expectPNG(PanelView().environment(store).environment(notesState(store, .all)).padding(Theme.Space.s3), named: "notes-panel-all")
    }

    @Test
    func rendersARowWithTheHoverTrash() throws {
        let (store, rich) = try sampleStore()
        let view = VStack(spacing: 0) {
            NoteRow(note: rich, days: store.dueDays, isHoveringAtStart: true)
            NoteRow(note: rich, days: store.dueDays, isSelected: true)
        }
        .frame(width: Theme.Panel.width - Theme.Panel.padding * 2)
        .padding(Theme.Panel.padding)
        .background(Theme.Panel.background)
        try expectPNG(view, named: "notes-row-hover-selected")
    }

    @Test
    func rendersThePanelDetail() async throws {
        let (store, rich) = try sampleStore()
        let state = notesState(store)
        state.openNote(rich.id)
        let harness = RichNoteHarness(PanelView().environment(store).environment(state), size: NSSize(width: Theme.Panel.width + 20, height: 1200))
        defer { harness.close() }
        await harness.fitAndSettle(width: Theme.Panel.width)
        let textView = try harness.textView()
        #expect(textView.string.hasPrefix("# Reunión con ventas"))
        try harness.screenshot(named: "notes-panel-detail")
    }

    @Test
    func rendersTheWindowAt980And2000WithANoteOpen() async throws {
        let (store, rich) = try sampleStore()
        let state = notesState(store)
        state.openNote(rich.id)
        try await window(store, state, width: 980, height: 900, named: "notes-window-980-detail")
        try await window(store, state, width: 2000, height: 1200, named: "notes-window-2000-detail")
    }

    @Test
    func rendersTheWindowWithNoNoteOpen() async throws {
        let (store, _) = try sampleStore()
        try await window(store, notesState(store), width: 980, height: 680, named: "notes-window-980-empty-detail")
    }

    @Test
    func rendersTheUndoBarAfterADelete() throws {
        let (store, rich) = try sampleStore()
        let recorder = ScheduleRecorder()
        let state = PanelState(store: store, noteFlow: NoteFlow(store: store, schedule: recorder.schedule))
        state.select(tab: .notes)
        state.deleteNote(rich.id)
        #expect(state.noteFlow.undo?.title == "Reunión con ventas")
        try expectPNG(PanelView().environment(store).environment(state).padding(Theme.Space.s3), named: "notes-panel-undo-delete")
    }

    @Test
    func rendersEachEmptyState() throws {
        let store = try makeStore(clock)
        let cases: [(DueFilter, String)] = [
            (.today, "today"),
            (.day("2026-11-16"), "yesterday"),
            (.week, "week"),
            (.all, "all"),
            (.day("2026-11-12"), "day"),
            (.range("2026-11-10", "2026-11-14"), "range"),
        ]
        for (filter, name) in cases {
            try expectPNG(
                PanelView().environment(store).environment(notesState(store, filter)).padding(Theme.Space.s3),
                named: "notes-empty-\(name)"
            )
        }
    }

    @Test
    func rendersTheFilterPopoverWithTheNoteOptions() throws {
        let (store, _) = try sampleStore()
        let days = store.dueDays
        let options = DueFilter.noteOptions(days)
        let counts = Dictionary(uniqueKeysWithValues: options.map { ($0, store.notes(in: $0, days: days).count) })
        #expect(counts[.today] == 2)
        #expect(counts[.yesterday(days)] == 1)
        #expect(counts[.week] == 3)
        try expectPNG(
            DueFilterPopover(
                selection: .today,
                days: days,
                counts: counts,
                options: options,
                optionTitle: { NoteFilterLabels.option($0, days) },
                onSelect: { _ in }
            ),
            named: "notes-filter-popover-day"
        )
        try expectPNG(
            DueFilterPopover(
                selection: .range("2026-11-10", "2026-11-17"),
                days: days,
                counts: counts,
                options: options,
                optionTitle: { NoteFilterLabels.option($0, days) },
                onSelect: { _ in }
            ),
            named: "notes-filter-popover-range"
        )
    }
}
