import Foundation
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct NoteFilterTests {
    let clock = TestClock("2026-11-17T10:24:00")

    private func note(_ created: String, _ body: String = "x") -> NoteItem {
        NoteItem(id: created, body: body, createdAt: localDate(created), updatedAt: localDate(created))
    }

    private var days: DueDays { DueDays(now: clock.date) }

    @Test
    func eachFilterKeepsTheNotesCreatedInItsSpan() {
        let notes = [
            note("2026-11-15T23:59:59"),
            note("2026-11-16T00:00:00"),
            note("2026-11-16T23:59:59"),
            note("2026-11-17T00:00:00"),
            note("2026-11-17T10:00:00"),
            note("2026-11-22T23:59:59"),
            note("2026-11-23T00:00:00"),
        ]
        func ids(_ filter: DueFilter) -> [String] {
            notes.filter { filter.includesNote($0, days) }.map(\.id)
        }
        #expect(ids(.today) == ["2026-11-17T00:00:00", "2026-11-17T10:00:00"])
        #expect(ids(.yesterday(days)) == ["2026-11-16T00:00:00", "2026-11-16T23:59:59"])
        #expect(ids(.week) == [
            "2026-11-16T00:00:00", "2026-11-16T23:59:59", "2026-11-17T00:00:00", "2026-11-17T10:00:00", "2026-11-22T23:59:59",
        ])
        #expect(ids(.day("2026-11-15")) == ["2026-11-15T23:59:59"])
        #expect(ids(.range("2026-11-15", "2026-11-16")) == ["2026-11-15T23:59:59", "2026-11-16T00:00:00", "2026-11-16T23:59:59"])
        #expect(ids(.range("2026-11-17", "2026-11-16")) == ids(.range("2026-11-16", "2026-11-17")))
        #expect(ids(.all).count == 7)
        #expect(ids(.overdue).count == 7)
        #expect(ids(.noDate).count == 7)
    }

    @Test
    func theStoreFiltersByCreationDate() throws {
        let store = try makeStore(clock)
        clock.date = localDate("2026-11-16T18:00:00")
        try store.addNote(body: "Ayer")
        clock.date = localDate("2026-11-17T10:24:00")
        try store.addNote(body: "Hoy")
        #expect(store.notes(in: .today).map(\.body) == ["Hoy"])
        #expect(store.notes(in: .yesterday(store.dueDays)).map(\.body) == ["Ayer"])
        #expect(store.notes(in: .week).map(\.body) == ["Hoy", "Ayer"])
        #expect(store.notes(in: .all).map(\.body) == ["Hoy", "Ayer"])
    }

    @Test
    func theOptionsAreTodasHoyAyerAndEstaSemana() {
        let options = DueFilter.noteOptions(days)
        #expect(options == [.all, .today, .day("2026-11-16"), .week])
        #expect(options.map { NoteFilterLabels.option($0, days) } == ["Todas", "Hoy", "Ayer", "Esta semana"])
    }

    @Test
    func theDayStepNeverGoesPastToday() {
        #expect(DueFilter.today.noteStepped(by: 1, days) == nil)
        #expect(DueFilter.today.noteStepped(by: -1, days) == .day("2026-11-16"))
        #expect(DueFilter.day("2026-11-16").noteStepped(by: 1, days) == .today)
        #expect(DueFilter.week.noteStepped(by: -1, days) == nil)
    }

    @Test
    func theFirstFilterComesFromTheSavedValueThenTheOldNoteScope() {
        #expect(DueFilter.noteStart(stored: nil, legacyScope: nil) == .today)
        #expect(DueFilter.noteStart(stored: nil, legacyScope: .day) == .today)
        #expect(DueFilter.noteStart(stored: nil, legacyScope: .week) == .week)
        #expect(DueFilter.noteStart(stored: .all, legacyScope: .week) == .all)
    }

    @Test
    func theHeaderSaysCreadas() {
        #expect(NoteFilterLabels.subtitle(.today, days, count: 2) == "martes 17 nov · creadas hoy")
        #expect(NoteFilterLabels.subtitle(.week, days, count: 2) == "16–22 nov · creadas esta semana")
        #expect(NoteFilterLabels.subtitle(.all, days, count: 1) == "1 nota")
        #expect(NoteFilterLabels.subtitle(.all, days, count: 4) == "4 notas")
        #expect(NoteFilterLabels.subtitle(.day("2026-11-16"), days, count: 0) == "creadas ayer")
        #expect(NoteFilterLabels.subtitle(.day("2026-11-12"), days, count: 0) == "creadas hace 5 días")
        #expect(NoteFilterLabels.subtitle(.range("2026-11-10", "2026-11-17"), days, count: 0) == "8 días")
    }

    @Test
    func eachFilterHasAnEmptyLine() {
        #expect(NoteFilterLabels.empty(.today, days) == "Sin notas de hoy.")
        #expect(NoteFilterLabels.empty(.week, days) == "Sin notas de esta semana.")
        #expect(NoteFilterLabels.empty(.all, days) == "Sin notas.")
        #expect(NoteFilterLabels.empty(.day("2026-11-19"), days) == "Sin notas del jueves 19 nov.")
        #expect(NoteFilterLabels.empty(.range("2026-11-10", "2026-11-17"), days) == "Sin notas en este rango.")
    }

    @Test
    func theRowDateIsTheTimeTodayThenTheWeekdayThenTheDay() {
        #expect(NoteFilterLabels.rowDate(localDate("2026-11-17T08:05:00"), days) == "08:05")
        #expect(NoteFilterLabels.rowDate(localDate("2026-11-16T23:00:00"), days) == "lun 16")
        #expect(NoteFilterLabels.rowDate(localDate("2026-11-11T09:00:00"), days) == "mié 11")
        #expect(NoteFilterLabels.rowDate(localDate("2026-11-10T09:00:00"), days) == "10 nov")
        #expect(NoteFilterLabels.rowDate(localDate("2025-12-29T00:00:00"), days) == "29 dic 2025")
    }

    @Test
    func theDetailMetaShowsTheCreationAndTheLastEdit() {
        let created = localDate("2026-11-17T09:00:00")
        var note = NoteItem(id: "n", body: "", createdAt: created, updatedAt: created)
        #expect(NoteFilterLabels.meta(note, days) == "Creada mar 17 nov · 09:00")
        note.updatedAt = localDate("2026-11-17T10:19:00")
        #expect(NoteFilterLabels.meta(note, days) == "Creada mar 17 nov · 09:00 · Editada hace 5 min")
        note.updatedAt = localDate("2026-11-17T09:10:00")
        #expect(NoteFilterLabels.meta(note, days) == "Creada mar 17 nov · 09:00 · Editada a las 09:10")
    }
}
