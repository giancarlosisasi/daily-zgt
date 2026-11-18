import AppKit
import MarkdownEngine
import SwiftUI
import UniformTypeIdentifiers

struct RichNoteFieldStyle: Equatable, Sendable {
    var text: TeclaTextStyle
    var minHeight: CGFloat
    var maxHeight: CGFloat?
    var padding: CGFloat

    static let window = RichNoteFieldStyle(
        text: TeclaTokens.TextStyles.small,
        minHeight: Theme.Notes.windowMinHeight,
        maxHeight: nil,
        padding: Theme.Notes.padding
    )

    static let panel = RichNoteFieldStyle(
        text: TeclaTokens.TextStyles.panel,
        minHeight: Theme.Notes.panelMinHeight,
        maxHeight: Theme.Notes.panelMaxHeight,
        padding: Theme.Notes.padding
    )

    static let page = RichNoteFieldStyle(
        text: TeclaTokens.TextStyles.small,
        minHeight: Theme.Notes.pageMinHeight,
        maxHeight: nil,
        padding: Theme.Notes.padding
    )

    static func of(_ layout: PanelLayout) -> RichNoteFieldStyle {
        layout == .window ? .window : .panel
    }
}

struct RichNoteField: View {
    @Binding var text: String
    let documentID: String
    let placeholder: String
    let images: NoteImageStore
    var style: RichNoteFieldStyle = .panel
    var focusOnAppear = false

    @Environment(\.isEnabled) private var isEnabled
    @State private var editorID: UUID
    @State private var isFocused = false
    @State private var widthEpoch = 0
    @State private var contentHeight: CGFloat = 0
    @State private var keys = RichNoteKeys()

    init(
        text: Binding<String>,
        documentID: String,
        placeholder: String,
        images: NoteImageStore,
        style: RichNoteFieldStyle = .panel,
        focusOnAppear: Bool = false,
        editorID: UUID = UUID()
    ) {
        _text = text
        self.documentID = documentID
        self.placeholder = placeholder
        self.images = images
        self.style = style
        self.focusOnAppear = focusOnAppear
        _editorID = State(initialValue: editorID)
    }

    private var bus: RichNoteBus {
        RichNoteBus(documentID: documentID, editorID: editorID)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Notes.radius, style: .continuous)
        capped(chrome)
            .clipShape(shape)
            .background(Theme.Notes.background, in: shape)
            .overlay {
                if isFocused {
                    shape.strokeBorder(Theme.Accent.focusRing, lineWidth: Theme.Accent.focusRingWidth)
                }
            }
            .onAppear {
                keys.names = bus
                keys.start()
                if focusOnAppear {
                    Task { @MainActor in isFocused = true }
                }
            }
            .onDisappear { keys.stop() }
            .onChange(of: isFocused) { _, focused in
                keys.isFocused = focused
                if focused {
                    Task { @MainActor in keys.adopt(NSApp.keyWindow?.firstResponder as? NSTextView) }
                }
            }
    }

    @ViewBuilder
    private func capped(_ content: some View) -> some View {
        if let maxHeight = style.maxHeight {
            ScrollView(.vertical) {
                content.background(GeometryReader { proxy in
                    Color.clear.preference(key: RichNoteHeightKey.self, value: proxy.size.height)
                })
            }
            .scrollIndicators(.automatic)
            .frame(height: min(max(contentHeight, style.minHeight), maxHeight))
            .onPreferenceChange(RichNoteHeightKey.self) { contentHeight = $0 }
        } else {
            content
        }
    }

    private var chrome: some View {
        editor
            .padding(style.padding)
            .frame(maxWidth: .infinity, minHeight: style.minHeight, alignment: .topLeading)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { focusAtEnd() }
            }
            .background(GeometryReader { proxy in
                Color.clear
                    .onAppear { Task { @MainActor in widthEpoch += 1 } }
                    .onChange(of: proxy.size.width) { _, _ in widthEpoch += 1 }
            })
    }

    private var editor: some View {
        NativeTextViewWrapper(
            text: $text,
            configuration: RichNoteConfiguration.make(
                style: style,
                images: RichNoteImageProvider(store: images, epoch: widthEpoch),
                bus: bus
            ),
            fontName: RichNoteConfiguration.fontName(style),
            fontSize: style.text.size,
            documentId: documentID,
            isEditable: isEnabled,
            isFocused: $isFocused,
            onPasteImage: { pasteboard in pasteImage(from: pasteboard) },
            placeholder: NSAttributedString(string: placeholder, attributes: [
                .font: TeclaFonts.nsFont(style.text),
                .foregroundColor: NSColor(TeclaTokens.Panel.dim),
            ])
        )
    }

    private func focusAtEnd() {
        guard isEnabled else { return }
        isFocused = true
        Task { @MainActor in
            guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
            textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
        }
    }

    private func pasteImage(from pasteboard: NSPasteboard) -> String? {
        guard let data = RichNotePasteboard.imageData(from: pasteboard),
              let encoded = NoteImageEncoder.encode(data),
              let id = try? images.insert(encoded, now: Date()) else { return nil }
        let textView = NSApp.keyWindow?.firstResponder as? NSTextView
        let current = textView?.string ?? text
        let selection = textView?.selectedRange() ?? NSRange(location: (current as NSString).length, length: 0)
        return NoteMarkdownRules.imagePasteInsertion(NoteImageStore.markdown(for: id), in: current, selection: selection)
    }
}

private struct RichNoteHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct RichNoteBus: Equatable, Sendable {
    let bold: Notification.Name
    let italic: Notification.Name
    let link: Notification.Name

    init(documentID: String, editorID: UUID) {
        let key = "\(documentID).\(editorID.uuidString)"
        bold = Notification.Name("zgt.note.bold.\(key)")
        italic = Notification.Name("zgt.note.italic.\(key)")
        link = Notification.Name("zgt.note.link.\(key)")
    }
}

struct RichNoteKeyPress: Sendable {
    var keyCode: UInt16
    var characters: String?
    var charactersIgnoringModifiers: String?
    var flags: NSEvent.ModifierFlags
    var windowNumber: Int

    init(keyCode: UInt16, characters: String?, charactersIgnoringModifiers: String?, flags: NSEvent.ModifierFlags, windowNumber: Int) {
        self.keyCode = keyCode
        self.characters = characters
        self.charactersIgnoringModifiers = charactersIgnoringModifiers
        self.flags = flags
        self.windowNumber = windowNumber
    }

    init(_ event: NSEvent) {
        self.init(
            keyCode: event.keyCode,
            characters: event.characters,
            charactersIgnoringModifiers: event.charactersIgnoringModifiers,
            flags: event.modifierFlags,
            windowNumber: event.windowNumber
        )
    }
}

@MainActor
final class RichNoteKeys {
    var names: RichNoteBus?
    var isFocused = false
    weak var textView: NSTextView?
    private var monitor: Any?
    private var undoObservers: [any NSObjectProtocol] = []

    func adopt(_ view: NSTextView?) {
        if let view {
            textView = view
        }
    }

    func windowDidChangeKey(_ window: NSWindow, isKey: Bool) {
        guard let textView, window === textView.window else { return }
        isFocused = isKey && window.firstResponder === textView
    }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let press = RichNoteKeyPress(event)
            let handled = MainActor.assumeIsolated { self?.handle(press) ?? false }
            return handled ? nil : event
        }
        for name in [Notification.Name.NSUndoManagerDidUndoChange, Notification.Name.NSUndoManagerDidRedoChange] {
            let observer = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { [weak self] notification in
                guard let manager = notification.object as? UndoManager else { return }
                let id = ObjectIdentifier(manager)
                MainActor.assumeIsolated { self?.undoDidChange(id) }
            }
            undoObservers.append(observer)
        }
        for (name, isKey) in [(NSWindow.didResignKeyNotification, false), (NSWindow.didBecomeKeyNotification, true)] {
            let observer = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { [weak self] notification in
                guard let window = notification.object as? NSWindow else { return }
                MainActor.assumeIsolated { self?.windowDidChangeKey(window, isKey: isKey) }
            }
            undoObservers.append(observer)
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        undoObservers.forEach(NotificationCenter.default.removeObserver)
        undoObservers.removeAll()
    }

    func undoDidChange(_ manager: ObjectIdentifier) {
        guard isFocused else { return }
        for window in NSApp.windows {
            guard let textView = window.firstResponder as? NSTextView,
                  let undoManager = textView.undoManager,
                  ObjectIdentifier(undoManager) == manager else { continue }
            textView.didChangeText()
            return
        }
    }

    func handle(_ press: RichNoteKeyPress) -> Bool {
        guard isFocused,
              let textView,
              let window = textView.window,
              window.windowNumber == press.windowNumber,
              window.firstResponder === textView,
              textView.isEditable,
              !textView.hasMarkedText() else { return false }
        let flags = press.flags.intersection([.command, .option, .control, .shift])
        if flags == .command, let names {
            switch press.charactersIgnoringModifiers?.lowercased() {
            case "b":
                NotificationCenter.default.post(name: names.bold, object: nil)
            case "i":
                NotificationCenter.default.post(name: names.italic, object: nil)
            case "k":
                let url = NoteMarkdownRules.linkURL(fromClipboard: NSPasteboard.general.string(forType: .string))
                NotificationCenter.default.post(name: names.link, object: nil, userInfo: ["url": url])
            default:
                return false
            }
            return true
        }
        guard flags.subtracting(.shift).isEmpty else { return false }
        if press.keyCode == 51, flags.isEmpty {
            return Self.apply(NoteMarkdownRules.blockBackspace(in: textView.string, selection: textView.selectedRange()), to: textView)
        }
        if press.characters == " " {
            return Self.apply(NoteMarkdownRules.checkboxShortcut(in: textView.string, selection: textView.selectedRange()), to: textView)
        }
        return false
    }

    static func apply(_ edit: NoteTextEdit?, to textView: NSTextView) -> Bool {
        guard let edit else { return false }
        textView.insertText(edit.replacement, replacementRange: edit.range)
        textView.setSelectedRange(NSRange(location: edit.caret, length: 0))
        return true
    }
}

enum RichNotePasteboard {
    static func imageData(from pasteboard: NSPasteboard) -> Data? {
        if let url = PasteboardImageReader.imageFileURL(from: pasteboard) {
            return try? Data(contentsOf: url)
        }
        let types = pasteboard.types ?? []
        let hasImage = types.contains { UTType($0.rawValue)?.conforms(to: .image) == true }
        guard hasImage, NoteMarkdownRules.pastesAsImage(text: pasteboard.string(forType: .string)) else { return nil }
        return PasteboardImageReader.imageData(from: pasteboard)
    }
}

struct RichNoteImageProvider: EmbeddedImageProvider {
    let store: NoteImageStore
    let epoch: Int

    func image(for reference: EmbeddedImageRequest) -> NSImage? {
        store.image(reference: reference.name)
    }

    func fingerprint() -> AnyHashable {
        [AnyHashable(store.version), AnyHashable(epoch)]
    }
}

struct RichNoteCodeHighlighter: SyntaxHighlighter {
    let background: NSColor

    func codeFont(size: CGFloat) -> NSFont {
        TeclaFonts.nsFont(TeclaTextStyle(
            size: size,
            lineHeight: TeclaTokens.TextStyles.code.lineHeight,
            trackingEm: 0,
            weight: TeclaTokens.TextStyles.code.weight,
            family: TeclaTokens.Fonts.mono
        ))
    }

    func backgroundColor() -> NSColor {
        background
    }

    func highlight(code: String, language: String?) -> NSAttributedString? {
        nil
    }

    var appearanceDidChangeNotification: Notification.Name? { nil }
}

enum RichNoteConfiguration {
    static func fontName(_ style: RichNoteFieldStyle) -> String {
        TeclaFonts.register()
        return TeclaFonts.nsFont(style.text).fontName
    }

    static var codeBackground: NSColor {
        let card = TeclaColor.over(TeclaTokens.Panel.card, TeclaTokens.Panel.bg)
        return NSColor(TeclaColor.over(TeclaTokens.Panel.in, card))
    }

    static var theme: MarkdownEditorTheme {
        MarkdownEditorTheme(
            bodyText: NSColor(TeclaTokens.Panel.text),
            mutedText: NSColor(TeclaTokens.Panel.dim),
            disabledText: NSColor(TeclaTokens.Panel.dim),
            headingMarker: NSColor(TeclaTokens.Panel.dim),
            link: NSColor(TeclaTokens.Panel.link),
            incompleteLink: NSColor(TeclaTokens.Panel.link),
            findMatchHighlight: NSColor(TeclaTokens.Panel.hl),
            findCurrentMatchHighlight: NSColor(TeclaTokens.Colors.accent),
            latexLightModeText: NSColor(TeclaTokens.Panel.text),
            latexDarkModeText: NSColor(TeclaTokens.Panel.text),
            strikethroughColor: NSColor(TeclaTokens.Panel.muted),
            highlightColor: NSColor(TeclaTokens.Panel.hl)
        )
    }

    static var taskCheckbox: TaskCheckboxStyle {
        TaskCheckboxStyle(box: TaskCheckboxBox(
            size: Theme.Notes.checkboxSize,
            gap: Theme.Notes.checkboxGap,
            cornerRadius: Theme.Checkbox.radius,
            borderWidth: Theme.Checkbox.borderWidth,
            fill: NSColor(Theme.Checkbox.fill),
            border: NSColor(Theme.Checkbox.border),
            checkedFill: NSColor(Theme.Checkbox.checkedFill),
            check: NSColor(Theme.Checkbox.check),
            checkRatio: Theme.Checkbox.checkRatio,
            checkImage: NSImage(named: Icon.check.rawValue)
        ))
    }

    static func headingMultipliers(_ style: RichNoteFieldStyle) -> [CGFloat] {
        let base = style.text.size
        let sizes = [
            TeclaTokens.TextStyles.subhead.size,
            TeclaTokens.TextStyles.panelTitle.size,
            max(TeclaTokens.TextStyles.small.size, base),
        ]
        return sizes.map { $0 / base } + [1, 1, 1]
    }

    static func make(
        style: RichNoteFieldStyle,
        images: any EmbeddedImageProvider,
        bus: RichNoteBus
    ) -> MarkdownEditorConfiguration {
        var configuration = MarkdownEditorConfiguration(
            theme: theme,
            services: MarkdownEditorServices(
                images: images,
                syntaxHighlighter: RichNoteCodeHighlighter(background: codeBackground)
            ),
            lists: ListStyle(autoClosePairsEnabled: false),
            headings: HeadingStyle(fontMultipliers: headingMultipliers(style)),
            paragraph: ParagraphStyle(spacingFactor: 0.3, lineHeightExtraSpacing: Theme.Notes.lineSpacing),
            scrollers: .hidden,
            spellChecking: SpellCheckingPolicy(
                continuousSpellChecking: false,
                grammarChecking: false,
                automaticSpellingCorrection: false,
                automaticQuoteSubstitution: false
            ),
            heightBehavior: .fitsContent
        )
        configuration.overscroll = OverscrollPolicy(percent: 0, maxPoints: 0, minPoints: 0)
        configuration.taskCheckbox = taskCheckbox
        configuration.imageEmbed.paragraphSpacing = Theme.Notes.imageSpacing
        configuration.extensions = [StrikethroughExtension()]
        configuration.services.bus.applyBoldRequest = bus.bold
        configuration.services.bus.applyItalicRequest = bus.italic
        configuration.services.bus.applyLinkRequest = bus.link
        return configuration
    }
}

extension NSColor {
    convenience init(_ token: TeclaColor) {
        self.init(srgbRed: token.red, green: token.green, blue: token.blue, alpha: token.alpha)
    }
}

extension TeclaColor {
    static func over(_ top: TeclaColor, _ bottom: TeclaColor) -> TeclaColor {
        let alpha = top.alpha + bottom.alpha * (1 - top.alpha)
        func channel(_ shift: UInt32) -> UInt32 {
            let topValue = Double((top.hex >> shift) & 0xFF)
            let bottomValue = Double((bottom.hex >> shift) & 0xFF)
            let mixed = (topValue * top.alpha + bottomValue * bottom.alpha * (1 - top.alpha)) / max(alpha, 0.0001)
            return UInt32(mixed.rounded()) << shift
        }
        return TeclaColor(hex: channel(16) | channel(8) | channel(0), alpha: alpha)
    }
}
