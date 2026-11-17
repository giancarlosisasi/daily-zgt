import Foundation
import Testing
@testable import DailyZGT

@Suite
struct NoteMarkdownRulesTests {
    private func caret(_ text: String, after needle: String) -> NSRange {
        let range = (text as NSString).range(of: needle)
        return NSRange(location: NSMaxRange(range), length: 0)
    }

    private func applied(_ edit: NoteTextEdit?, to text: String) -> String? {
        edit.map { (text as NSString).replacingCharacters(in: $0.range, with: $0.replacement) }
    }

    private func engineBlockEmbed(_ embed: String, in text: String, selection: NSRange) -> String {
        let ns = text as NSString
        var prefix = ""
        var suffix = ""
        if selection.location > 0, ns.character(at: selection.location - 1) != 0x0A {
            prefix = "\n"
        }
        let after = NSMaxRange(selection)
        if after < ns.length, ns.character(at: after) != 0x0A {
            suffix = "\n"
        }
        return ns.replacingCharacters(in: selection, with: prefix + embed + suffix)
    }

    private func pasted(into text: String, at selection: NSRange) -> String {
        let image = "![](zgt-image:abc)"
        let embed = NoteMarkdownRules.imagePasteInsertion(image, in: text, selection: selection)
        return engineBlockEmbed(embed, in: text, selection: selection)
    }

    @Test(arguments: [
        ("## Dos", "## ", "Dos"),
        ("# Uno", "# ", "Uno"),
        ("### Tres", "### ", "Tres"),
        ("- dos", "- ", "dos"),
        ("* dos", "* ", "dos"),
        ("1. dos", "1. ", "dos"),
        ("12) dos", "12) ", "dos"),
        ("- [ ] tarea", "- [ ] ", "tarea"),
        ("- [x] hecha", "- [x] ", "hecha"),
        ("> cita", "> ", "cita"),
        ("- ", "- ", ""),
    ])
    func backspaceAfterABlockPrefixRemovesTheWholePrefix(text: String, prefix: String, result: String) {
        let edit = NoteMarkdownRules.blockBackspace(in: text, selection: caret(text, after: prefix))
        #expect(applied(edit, to: text) == result)
        #expect(edit?.caret == 0)
    }

    @Test
    func backspaceOnANestedItemOutdentsFirst() {
        let text = "- uno\n\t\t- dos"
        let edit = NoteMarkdownRules.blockBackspace(in: text, selection: caret(text, after: "\t\t- "))
        #expect(applied(edit, to: text) == "- uno\n\t- dos")
    }

    @Test
    func backspaceOnASecondLineTouchesOnlyThatLine() {
        let text = "Intro\n## Dos\nfin"
        let edit = NoteMarkdownRules.blockBackspace(in: text, selection: caret(text, after: "## "))
        #expect(applied(edit, to: text) == "Intro\nDos\nfin")
        #expect(edit?.caret == 6)
    }

    @Test(arguments: [
        ("## Dos", NSRange(location: 4, length: 0)),
        ("## Dos", NSRange(location: 3, length: 2)),
        ("plain text", NSRange(location: 5, length: 0)),
        ("##Dos", NSRange(location: 2, length: 0)),
        ("", NSRange(location: 0, length: 0)),
        ("- dos", NSRange(location: 0, length: 0)),
    ])
    func backspaceElsewhereKeepsTheNormalDelete(text: String, selection: NSRange) {
        #expect(NoteMarkdownRules.blockBackspace(in: text, selection: selection) == nil)
    }

    @Test(arguments: [
        ("[ ]", "- [ ] "),
        ("[]", "- [ ] "),
        ("uno\n[ ]", "uno\n- [ ] "),
        ("\t[ ]", "\t- [ ] "),
    ])
    func spaceAfterABoxAtTheLineStartMakesACheckbox(text: String, result: String) {
        let selection = NSRange(location: (text as NSString).length, length: 0)
        let edit = NoteMarkdownRules.checkboxShortcut(in: text, selection: selection)
        #expect(applied(edit, to: text) == result)
        #expect(edit?.caret == (result as NSString).length)
    }

    @Test(arguments: ["texto [ ]", "- [ ]", "[x]", "[ ] ya"])
    func spaceElsewhereIsAPlainSpace(text: String) {
        let selection = NSRange(location: (text as NSString).length, length: 0)
        #expect(NoteMarkdownRules.checkboxShortcut(in: text, selection: selection) == nil)
    }

    @Test
    func anImagePastedInAnEmptyNoteGetsALineAfterIt() {
        #expect(pasted(into: "", at: NSRange(location: 0, length: 0)) == "![](zgt-image:abc)\n")
    }

    @Test
    func anImagePastedAtTheEndOfAWordGetsABlankLineBefore() {
        #expect(pasted(into: "Antes", at: NSRange(location: 5, length: 0)) == "Antes\n\n![](zgt-image:abc)\n")
    }

    @Test
    func anImagePastedInsideALineSplitsItWithBlankLines() {
        #expect(pasted(into: "Antes despues", at: NSRange(location: 6, length: 0)) == "Antes \n\n![](zgt-image:abc)\n\ndespues")
    }

    @Test
    func anImagePastedOnAnEmptyLineBetweenParagraphsAddsNoExtraLines() {
        let text = "Uno\n\n\n\nDos"
        #expect(pasted(into: text, at: NSRange(location: 5, length: 0)) == "Uno\n\n![](zgt-image:abc)\n\n\nDos")
    }

    @Test
    func anImagePastedAtTheStartOfALineAfterTextGetsBlankLinesAround() {
        let text = "Uno\nDos"
        #expect(pasted(into: text, at: NSRange(location: 4, length: 0)) == "Uno\n\n![](zgt-image:abc)\n\nDos")
    }

    @Test
    func anImagePastedOverASelectionReplacesIt() {
        let text = "Uno CAMBIO Dos"
        #expect(pasted(into: text, at: NSRange(location: 4, length: 6)) == "Uno \n\n![](zgt-image:abc)\n\n Dos")
    }

    @Test(arguments: [
        (nil as String?, true),
        ("", true),
        ("https://example.com/foto.png", true),
        ("file:///Users/gio/foto.png", true),
        ("foto.png", false),
        ("Una frase copiada", false),
        ("https://example.com y mas", false),
    ])
    func onlyAnImageWithNoTextPastesAsAnImage(text: String?, image: Bool) {
        #expect(NoteMarkdownRules.pastesAsImage(text: text) == image)
    }

    @Test(arguments: [
        (nil as String?, ""),
        ("https://zgt.dev", "https://zgt.dev"),
        (" https://zgt.dev\n", "https://zgt.dev"),
        ("mailto:gio@example.com", "mailto:gio@example.com"),
        ("una frase", ""),
        ("javascript:alert(1)", ""),
    ])
    func cmdKUsesAWebAddressFromTheClipboard(text: String?, url: String) {
        #expect(NoteMarkdownRules.linkURL(fromClipboard: text) == url)
    }
}
