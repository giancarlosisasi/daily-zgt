import AppKit
import Observation
import SwiftUI
@testable import DailyZGT

@Observable
@MainActor
final class NoteBox {
    var text: String

    init(_ text: String) {
        self.text = text
    }
}

struct RichNoteHost: View {
    @Bindable var box: NoteBox
    let documentID: String
    let images: NoteImageStore
    var style: RichNoteFieldStyle = .window
    var width: CGFloat = 480

    var body: some View {
        RichNoteField(
            text: $box.text,
            documentID: documentID,
            placeholder: "Contexto, links, lo que falta",
            images: images,
            style: style
        )
        .frame(width: width)
        .padding(Theme.Space.s3)
        .background(Theme.Panel.background)
    }
}

@MainActor
final class RichNoteHarness {
    let window: NSWindow
    let host: NSView

    init(_ root: some View, size: NSSize = NSSize(width: 520, height: 420)) {
        let hosting = NSHostingView(rootView: AnyView(root.environment(\.colorScheme, .dark)))
        hosting.appearance = NSAppearance(named: .darkAqua)
        hosting.frame = NSRect(origin: .zero, size: size)
        window = NSWindow(
            contentRect: NSRect(x: -4000, y: -4000, width: size.width, height: size.height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = hosting
        host = hosting
    }

    var textViews: [NSTextView] {
        Self.textViews(in: host)
    }

    func textView(at index: Int = 0) throws -> NSTextView {
        let all = textViews
        guard all.indices.contains(index) else { throw ScreenshotError.renderFailed }
        return all[index]
    }

    func focus(_ textView: NSTextView, at location: Int? = nil) async {
        window.makeFirstResponder(textView)
        let end = (textView.string as NSString).length
        textView.setSelectedRange(NSRange(location: location ?? end, length: 0))
        await Self.settle()
    }

    func type(_ text: String, into textView: NSTextView) async {
        for character in text {
            let chars = character == "\n" ? "\r" : String(character)
            if let event = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber,
                context: nil,
                characters: chars,
                charactersIgnoringModifiers: chars,
                isARepeat: false,
                keyCode: character == "\n" ? 36 : 0
            ) {
                textView.keyDown(with: event)
            }
            await Self.settle(10)
        }
        await Self.settle()
    }

    func tab(_ textView: NSTextView) async {
        if let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            characters: "\t",
            charactersIgnoringModifiers: "\t",
            isARepeat: false,
            keyCode: 48
        ) {
            textView.keyDown(with: event)
        }
        await Self.settle()
    }

    func press(keyCode: UInt16, characters: String, flags: NSEvent.ModifierFlags = []) -> RichNoteKeyPress {
        RichNoteKeyPress(
            keyCode: keyCode,
            characters: characters,
            charactersIgnoringModifiers: characters,
            flags: flags,
            windowNumber: window.windowNumber
        )
    }

    func fitAndSettle(width: CGFloat) async {
        for _ in 0 ..< 4 {
            let height = max(host.fittingSize.height, 1)
            let size = NSSize(width: width, height: height)
            window.setContentSize(size)
            host.frame = NSRect(origin: .zero, size: size)
            host.layoutSubtreeIfNeeded()
            await Self.settle(150)
        }
    }

    @discardableResult
    func screenshot(named name: String) throws -> URL {
        host.layoutSubtreeIfNeeded()
        host.display()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw ScreenshotError.renderFailed
        }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw ScreenshotError.encodeFailed
        }
        return try Screenshot.save(data, named: name)
    }

    func close() {
        window.orderOut(nil)
        window.close()
    }

    static func settle(_ milliseconds: Int = 200) async {
        let deadline = Date().addingTimeInterval(Double(milliseconds) / 1000)
        while Date() < deadline {
            spin(until: min(deadline, Date().addingTimeInterval(0.02)))
            await Task.yield()
        }
    }

    static func spin(until date: Date) {
        RunLoop.main.run(mode: .default, before: date)
    }

    static func eventBoundary() async {
        if let event = NSEvent.otherEvent(
            with: .applicationDefined,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            subtype: 0,
            data1: 0,
            data2: 0
        ) {
            NSApp.postEvent(event, atStart: false)
        }
        await settle(100)
    }

    static func textViews(in view: NSView) -> [NSTextView] {
        var found: [NSTextView] = []
        if let textView = view as? NSTextView {
            found.append(textView)
        }
        for subview in view.subviews {
            found += textViews(in: subview)
        }
        return found
    }
}

struct ClipboardBackup {
    let items: [[(NSPasteboard.PasteboardType, Data)]]

    @MainActor
    static func save() -> ClipboardBackup {
        let items = NSPasteboard.general.pasteboardItems ?? []
        return ClipboardBackup(items: items.map { item in
            item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
        })
    }

    @MainActor
    func restore() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let restored = items.map { pairs -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in pairs {
                item.setData(data, forType: type)
            }
            return item
        }
        if !restored.isEmpty {
            pasteboard.writeObjects(restored)
        }
    }
}
