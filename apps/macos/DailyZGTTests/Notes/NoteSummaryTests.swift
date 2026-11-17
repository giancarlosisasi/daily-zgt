import Testing
@testable import DailyZGT

@Suite
struct NoteSummaryTests {
    @Test
    func theFirstLineIsTheTitleAndTheNextLineIsThePreview() {
        let summary = NoteSummary.make("# Reunión con ventas\n\nConfirmar fecha de **OTP** con el equipo\n- Otro punto")
        #expect(summary == NoteSummary(title: "Reunión con ventas", preview: "Confirmar fecha de OTP con el equipo"))
    }

    @Test
    func theMarkersAreStripped() {
        #expect(NoteSummary.plain("## Plan *de* la _semana_") == "Plan de la semana")
        #expect(NoteSummary.plain("> Cita con `código`") == "Cita con código")
        #expect(NoteSummary.plain("- [ ] Tarea abierta") == "Tarea abierta")
        #expect(NoteSummary.plain("- [x] Tarea hecha") == "Tarea hecha")
        #expect(NoteSummary.plain("12. Punto doce") == "Punto doce")
        #expect(NoteSummary.plain("* ~~Tachado~~") == "Tachado")
        #expect(NoteSummary.plain("Ver [la guía](https://example.com) hoy") == "Ver la guía hoy")
        #expect(NoteSummary.plain("snake_case_name") == "snake_case_name")
        #expect(NoteSummary.plain("---") == "")
        #expect(NoteSummary.plain("![](zgt-image:abc)") == "Imagen")
    }

    @Test
    func emptyLinesAndRulesAreSkipped() {
        let summary = NoteSummary.make("\n   \n---\nTítulo\n\n\n***\nDetalle")
        #expect(summary == NoteSummary(title: "Título", preview: "Detalle"))
    }

    @Test
    func aCodeFenceShowsItsCode() {
        let summary = NoteSummary.make("```swift\nlet x = 1\n```")
        #expect(summary == NoteSummary(title: "let x = 1", preview: nil))
    }

    @Test
    func anEmptyNoteHasTheEmptyTitleAndNoPreview() {
        #expect(NoteSummary.make("") == NoteSummary(title: "Nota vacía", preview: nil))
        #expect(NoteSummary.make("  \n# \n") == NoteSummary(title: "Nota vacía", preview: nil))
        #expect(NoteSummary.make("Solo una línea").preview == nil)
    }
}
