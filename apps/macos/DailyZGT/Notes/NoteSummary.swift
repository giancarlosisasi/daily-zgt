import Foundation

struct NoteSummary: Equatable, Sendable {
    let title: String
    let preview: String?

    static func make(_ body: String) -> NoteSummary {
        var lines: [String] = []
        var inFence = false
        for raw in body.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inFence.toggle()
                continue
            }
            let line = inFence ? trimmed : plain(String(raw))
            if !line.isEmpty {
                lines.append(line)
            }
            if lines.count == 2 { break }
        }
        guard let title = lines.first else {
            return NoteSummary(title: NoteFilterLabels.untitled, preview: nil)
        }
        return NoteSummary(title: title, preview: lines.dropFirst().first)
    }

    static func plain(_ line: String) -> String {
        var text = line.trimmingCharacters(in: .whitespaces)
        if text.range(of: #"^([-*_])(\s*\1){2,}$"#, options: .regularExpression) != nil {
            return ""
        }
        let blockMarkers = [
            #"^(>\s*)+"#,
            #"^#{1,6}(\s+|$)"#,
            #"^([-*+]|\d+[.)])\s+"#,
            #"^\[[ xX]\]\s+"#,
        ]
        for pattern in blockMarkers {
            text = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        let hadImage = text.contains("![")
        text = text.replacingOccurrences(of: #"!\[[^\]]*\]\([^)]*\)"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\[([^\]]*)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(\*\*|__|~~|`)"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?<![\p{L}\p{N}])[*_]|[*_](?![\p{L}\p{N}])"#, with: "", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespaces)
        if text.isEmpty && hadImage {
            return NoteFilterLabels.imageOnly
        }
        return text
    }
}
