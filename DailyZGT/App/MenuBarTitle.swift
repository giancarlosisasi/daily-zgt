import Foundation

enum MenuBarTitle {
    static let maxLength = 24
    static let ellipsis: Character = "…"
    static let key = AppStateKey(name: "menu_bar_title", defaultValue: true)

    static func text(for title: String?) -> String? {
        guard let title else { return nil }
        let clean = title
            .split(whereSeparator: \.isNewline)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return nil }
        guard clean.count > maxLength else { return clean }
        var head = String(clean.prefix(maxLength - 1))
        while head.last?.isWhitespace == true {
            head.removeLast()
        }
        return head + String(ellipsis)
    }
}

extension AppStore {
    var menuBarTitleIsOn: Bool {
        value(for: MenuBarTitle.key)
    }

    var menuBarTitle: String? {
        menuBarTitleIsOn ? openPriorities(in: .today).first?.title : nil
    }
}
