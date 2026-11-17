import AppKit
import SwiftUI
import Testing
@testable import DailyZGT

@Suite(.serialized)
@MainActor
struct RichNoteFieldTests {
    static func sampleNote(image: String) -> String {
        """
        # Plan de la semana
        Revisar **el brief** con _ventas_, ~~cerrar~~ el [ticket](https://zgt.dev) y `npm run build`.

        ## Pasos
        - Listar las apps piloto
        \t- Escribir los criterios
        1. Confirmar la fecha
        2. Enviar el resumen
        - [x] Llamar a Ana
        - [ ] Mandar el correo

        ### Nota
        > Lo importante es la fecha de OTP.

        ```swift
        let otp = "1234"
        print(otp)
        ```

        | Tarea | Estado |
        | --- | --- |
        | OTP | hecho |
        | SMS | pendiente |

        ---

        \(NoteImageStore.markdown(for: image))
        Fin de la nota.
        """
    }

    private func open(_ text: String, id: String = "note-a", images: NoteImageStore) async throws -> (RichNoteHarness, NoteBox, NSTextView) {
        let box = NoteBox(text)
        let harness = RichNoteHarness(RichNoteHost(box: box, documentID: id, images: images))
        await RichNoteHarness.settle(300)
        let textView = try harness.textView()
        await harness.focus(textView)
        return (harness, box, textView)
    }

    private func font(_ textView: NSTextView, at needle: String, offset: Int = 0) throws -> NSFont {
        let range = (textView.string as NSString).range(of: needle)
        try #require(range.location != NSNotFound)
        return try #require(textView.textStorage?.attribute(.font, at: range.location + offset, effectiveRange: nil) as? NSFont)
    }

    private func isHidden(_ textView: NSTextView, at needle: String) throws -> Bool {
        let range = (textView.string as NSString).range(of: needle)
        try #require(range.location != NSNotFound)
        let attributes = try #require(textView.textStorage?.attributes(at: range.location, effectiveRange: nil))
        let tiny = ((attributes[.font] as? NSFont)?.pointSize ?? 99) < 1
        let clear = ((attributes[.foregroundColor] as? NSColor)?.alphaComponent ?? 1) == 0
        return tiny || clear
    }

    @Test
    func aHeadingConvertsWhileTypingAndHidesItsMarkersOnTheCaretLine() async throws {
        let (harness, box, textView) = try await open("", images: NoteImageStore(database: try AppDatabase.inMemory()))
        defer { harness.close() }
        await harness.type("## Dos", into: textView)
        #expect(box.text == "## Dos")
        #expect(textView.selectedRange().location == 6)
        #expect(try font(textView, at: "Dos").pointSize == TeclaTokens.TextStyles.panelTitle.size)
        #expect(try font(textView, at: "Dos").fontDescriptor.symbolicTraits.contains(.bold))
        #expect(try isHidden(textView, at: "##"))
    }

    @Test
    func aQuoteMarkerStaysHiddenOnTheCaretLine() async throws {
        let (harness, _, textView) = try await open("> cita", images: NoteImageStore(database: try AppDatabase.inMemory()))
        defer { harness.close() }
        #expect(textView.selectedRange().location == 6)
        #expect(try isHidden(textView, at: ">"))
    }

    @Test
    func italicTextIsOblique() async throws {
        let (harness, _, textView) = try await open("_hola_ y fin", images: NoteImageStore(database: try AppDatabase.inMemory()))
        defer { harness.close() }
        let italic = try font(textView, at: "hola")
        let plain = try font(textView, at: "fin")
        #expect(italic.matrix[2] > 0)
        #expect(plain.matrix[2] == 0)
    }

    @Test
    func tabOnANumberedItemRestartsTheNestedListAtOne() async throws {
        let (harness, box, textView) = try await open("", images: NoteImageStore(database: try AppDatabase.inMemory()))
        defer { harness.close() }
        await harness.type("1. uno\ndos\n", into: textView)
        #expect(box.text == "1. uno\n2. dos\n3. ")
        await harness.tab(textView)
        await harness.type("sub", into: textView)
        #expect(box.text == "1. uno\n2. dos\n\t1. sub")
    }

    @Test(arguments: [
        ("## Dos", "## "),
        ("- dos", "- "),
        ("1. dos", "1. "),
        ("- [ ] dos", "- [ ] "),
        ("> dos", "> "),
    ])
    func backspaceAtTheStartOfABlockMakesAParagraphAndOneUndoRestoresIt(text: String, prefix: String) async throws {
        let (harness, box, textView) = try await open(text, images: NoteImageStore(database: try AppDatabase.inMemory()))
        defer { harness.close() }
        await harness.focus(textView, at: (prefix as NSString).length)
        let keys = RichNoteKeys()
        keys.isFocused = true
        #expect(keys.handle(harness.press(keyCode: 51, characters: "\u{7F}")))
        await RichNoteHarness.settle()
        #expect(box.text == String(text.dropFirst(prefix.count)))
        #expect(textView.selectedRange().location == 0)
        await RichNoteHarness.eventBoundary()
        NSApp.sendAction(Selector(("undo:")), to: textView, from: nil)
        await RichNoteHarness.settle()
        #expect(textView.string == text)
        #expect(box.text == text)
    }

    @Test
    func backspaceInsideTheTextKeepsTheNormalDelete() async throws {
        let (harness, _, textView) = try await open("## Dos", images: NoteImageStore(database: try AppDatabase.inMemory()))
        defer { harness.close() }
        let keys = RichNoteKeys()
        keys.isFocused = true
        #expect(!keys.handle(harness.press(keyCode: 51, characters: "\u{7F}")))
        keys.isFocused = false
        await harness.focus(textView, at: 3)
        #expect(!keys.handle(harness.press(keyCode: 51, characters: "\u{7F}")))
    }

    @Test
    func aBoxAndASpaceAtTheLineStartBecomeACheckbox() async throws {
        let (harness, box, textView) = try await open("", images: NoteImageStore(database: try AppDatabase.inMemory()))
        defer { harness.close() }
        await harness.type("[ ]", into: textView)
        let keys = RichNoteKeys()
        keys.isFocused = true
        #expect(keys.handle(harness.press(keyCode: 49, characters: " ")))
        await harness.type("tarea", into: textView)
        #expect(box.text == "- [ ] tarea")
    }

    @Test
    func cmdBActsOnlyOnTheFocusedNote() async throws {
        let images = NoteImageStore(database: try AppDatabase.inMemory())
        let first = NoteBox("uno palabra")
        let second = NoteBox("otro palabra")
        let harness = RichNoteHarness(VStack {
            RichNoteHost(box: first, documentID: "note-a", images: images)
            RichNoteHost(box: second, documentID: "note-b", images: images)
        }, size: NSSize(width: 520, height: 640))
        defer { harness.close() }
        await RichNoteHarness.settle(300)
        #expect(harness.textViews.count == 2)
        let textView = try harness.textView(at: 0)
        await harness.focus(textView)
        textView.setSelectedRange((textView.string as NSString).range(of: "palabra"))
        let keys = RichNoteKeys()
        keys.names = RichNoteBus(documentID: "note-a")
        keys.isFocused = true
        #expect(keys.handle(harness.press(keyCode: 11, characters: "b", flags: .command)))
        await RichNoteHarness.settle()
        #expect(first.text == "uno **palabra**")
        #expect(second.text == "otro palabra")
    }

    @Test
    func cmdVOfAnImageStoresItAndInsertsItAsItsOwnBlock() async throws {
        let store = try makeStore()
        let (harness, box, textView) = try await open("Antes", images: store.images)
        defer { harness.close() }
        let backup = ClipboardBackup.save()
        defer { backup.restore() }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(TestImages.png(width: 3000, height: 1000, alpha: true), forType: .png)
        textView.paste(nil)
        await RichNoteHarness.settle(400)
        let ids: [String] = try values("SELECT id FROM image", in: store.database)
        let id = try #require(ids.first)
        #expect(ids.count == 1)
        #expect(box.text == "Antes\n\n![](zgt-image:\(id))\n")
        #expect(textView.selectedRange().location == (box.text as NSString).length)
        let widths: [Int] = try values("SELECT width FROM image", in: store.database)
        #expect(widths == [2400])
        await RichNoteHarness.eventBoundary()
        NSApp.sendAction(Selector(("undo:")), to: textView, from: nil)
        await RichNoteHarness.settle()
        #expect(box.text == "Antes")
        #expect(try values("SELECT COUNT(*) FROM image", in: store.database) as [Int] == [1])
    }

    @Test
    func aTextPasteWithAnImageFlavorStaysText() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("zgt.test.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("Una frase copiada de Word", forType: .string)
        pasteboard.setData(TestImages.png(width: 20, height: 20, alpha: false), forType: .png)
        #expect(RichNotePasteboard.imageData(from: pasteboard) == nil)
        pasteboard.clearContents()
        pasteboard.setData(TestImages.png(width: 20, height: 20, alpha: false), forType: .png)
        #expect(RichNotePasteboard.imageData(from: pasteboard) != nil)
    }

    @Test
    func theCodeBackgroundIsOpaque() {
        #expect(RichNoteConfiguration.codeBackground.alphaComponent == 1)
    }

    @Test
    func rendersTheRichNoteInTheWindowDetail() async throws {
        let store = try makeStore(TestClock("2026-10-12T10:00:00"))
        let image = try store.images.insert(
            try #require(NoteImageEncoder.encode(TestImages.png(width: 1200, height: 420, alpha: true))),
            now: store.now()
        )
        let priority = try store.addPriority(
            title: "Ventas: confirmar la integracion de WhatsApp",
            level: .high,
            list: .today,
            note: Self.sampleNote(image: image)
        )
        let state = PanelState(store: store)
        let view = PriorityDetailView(priority: priority)
            .environment(store)
            .environment(state)
            .environment(\.panelLayout, .window)
            .frame(width: Theme.Window.readableWidth)
            .padding(Theme.Space.s5)
            .background(Theme.Panel.background)
        let harness = RichNoteHarness(view, size: NSSize(width: Theme.Window.readableWidth + Theme.Space.s5 * 2, height: 1600))
        defer { harness.close() }
        await harness.fitAndSettle(width: Theme.Window.readableWidth + Theme.Space.s5 * 2)
        let textView = try harness.textView()
        #expect(textView.string.contains("zgt-image:\(image)"))
        #expect(store.images.loadCount == 1)
        let url = try harness.screenshot(named: "rich-note-window-detail")
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func rendersTheRichNoteInThePanelDetail() async throws {
        let store = try makeStore(TestClock("2026-10-12T10:00:00"))
        let image = try store.images.insert(
            try #require(NoteImageEncoder.encode(TestImages.png(width: 1200, height: 420, alpha: true))),
            now: store.now()
        )
        let priority = try store.addPriority(
            title: "Ventas: confirmar la integracion de WhatsApp",
            level: .high,
            list: .today,
            note: Self.sampleNote(image: image)
        )
        let state = PanelState(store: store)
        state.openDetail(priority.id)
        let view = PriorityDetailView(priority: priority)
            .environment(store)
            .environment(state)
            .panelChrome()
        let harness = RichNoteHarness(view, size: NSSize(width: Theme.Panel.width + 20, height: 1200))
        defer { harness.close() }
        await harness.fitAndSettle(width: Theme.Panel.width)
        let url = try harness.screenshot(named: "rich-note-panel-detail")
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func rendersAnEmptyNoteWithItsPlaceholderAndMinimumHeight() async throws {
        let images = NoteImageStore(database: try AppDatabase.inMemory())
        let harness = RichNoteHarness(VStack(alignment: .leading, spacing: Theme.Space.s3) {
            RichNoteHost(box: NoteBox(""), documentID: "empty-window", images: images, style: .window, width: Theme.Window.readableWidth)
            RichNoteHost(box: NoteBox(""), documentID: "empty-panel", images: images, style: .panel, width: Theme.Panel.width - Theme.Panel.padding * 2)
        }, size: NSSize(width: 600, height: 600))
        defer { harness.close() }
        await harness.fitAndSettle(width: Theme.Window.readableWidth + Theme.Space.s3 * 2)
        try harness.screenshot(named: "rich-note-empty")
        #expect(harness.host.fittingSize.height >= Theme.Notes.windowMinHeight + Theme.Notes.panelMinHeight)
    }
}
