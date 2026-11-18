import Foundation

struct NoteTextEdit: Equatable, Sendable {
    var range: NSRange
    var replacement: String
    var caret: Int {
        range.location + (replacement as NSString).length
    }
}

enum NoteMarkdownRules {
    private static let blockPrefix = try! NSRegularExpression(
        pattern: #"^(\t*)(#{1,6} |[-*+] \[[ xX]\] |[-*+] |\d+[.)] \[[ xX]\] |\d+[.)] |> ?)$"#
    )
    private static let checkboxHead = try! NSRegularExpression(pattern: #"^(\t*)(\[ ?\])$"#)

    static func blockBackspace(in text: String, selection: NSRange) -> NoteTextEdit? {
        guard selection.length == 0 else { return nil }
        let ns = text as NSString
        guard selection.location <= ns.length else { return nil }
        let line = ns.lineRange(for: NSRange(location: selection.location, length: 0))
        let headRange = NSRange(location: line.location, length: selection.location - line.location)
        guard headRange.length > 0 else { return nil }
        let head = ns.substring(with: headRange)
        guard let match = blockPrefix.firstMatch(in: head, range: NSRange(location: 0, length: headRange.length)) else {
            return nil
        }
        if match.range(at: 1).length > 0 {
            return NoteTextEdit(range: NSRange(location: line.location, length: 1), replacement: "")
        }
        return NoteTextEdit(range: headRange, replacement: "")
    }

    static func checkboxShortcut(in text: String, selection: NSRange) -> NoteTextEdit? {
        guard selection.length == 0 else { return nil }
        let ns = text as NSString
        guard selection.location <= ns.length else { return nil }
        let line = ns.lineRange(for: NSRange(location: selection.location, length: 0))
        let headRange = NSRange(location: line.location, length: selection.location - line.location)
        let head = ns.substring(with: headRange)
        guard let match = checkboxHead.firstMatch(in: head, range: NSRange(location: 0, length: headRange.length)) else {
            return nil
        }
        let box = match.range(at: 2)
        return NoteTextEdit(range: NSRange(location: line.location + box.location, length: box.length), replacement: "- [ ] ")
    }

    static func imagePasteInsertion(_ image: String, in text: String, selection: NSRange) -> String {
        let ns = text as NSString
        let start = min(selection.location, ns.length)
        let end = min(NSMaxRange(selection), ns.length)
        let before = ns.substring(to: start)
        let after = ns.substring(from: end)
        var lead = ""
        if !before.isEmpty {
            let wanted = 2 - min(2, trailingNewlines(before))
            lead = String(repeating: "\n", count: before.hasSuffix("\n") ? wanted : wanted - 1)
        }
        var trail = "\n"
        if !after.isEmpty {
            let wanted = 2 - min(2, leadingNewlines(after))
            trail = String(repeating: "\n", count: max(1, after.hasPrefix("\n") ? wanted : wanted - 1))
        }
        return lead + image + trail
    }

    static func pastesAsImage(text: String?) -> Bool {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return true }
        guard !text.contains(where: \.isWhitespace), let url = URL(string: text), let scheme = url.scheme?.lowercased() else {
            return false
        }
        return scheme == "http" || scheme == "https" || scheme == "file"
    }

    static func linkURL(fromClipboard text: String?) -> String {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.contains(where: \.isWhitespace),
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" || scheme == "mailto" else { return "" }
        return text
    }

    private static func trailingNewlines(_ text: String) -> Int {
        text.reversed().prefix { $0 == "\n" }.count
    }

    private static func leadingNewlines(_ text: String) -> Int {
        text.prefix { $0 == "\n" }.count
    }
}
