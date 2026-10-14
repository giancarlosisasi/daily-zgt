import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct NotesViewTests {
    let clock = TestClock("2026-10-12T10:24:00")

    private func render(_ store: AppStore, scope: NoteScope, named name: String) throws {
        let view = NotesView(scope: scope).environment(store).panelChrome()
        let url = try Screenshot.writeHosted(view, named: name)
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func rendersTheDayNoteEmptyWithThePlaceholder() throws {
        try render(try makeStore(clock), scope: .day, named: "notes-today-empty")
    }

    @Test
    func rendersTheDayNoteWithText() throws {
        let store = try makeStore(clock)
        try store.saveNote(
            "Hablar con Ana sobre el brief.\nRevisar el MR de compass.ui antes de la demo.\n- Pedir acceso al dashboard",
            scope: .day
        )
        try render(store, scope: .day, named: "notes-today-text")
    }

    @Test
    func rendersTheWeekNoteWithText() throws {
        let store = try makeStore(clock)
        try store.saveNote("Cerrar el brief de Tailwind v4 el jueves.\nPreparar la demo del viernes.", scope: .week)
        try store.saveNote("Not this one", scope: .day)
        try render(store, scope: .week, named: "notes-week-text")
    }
}
