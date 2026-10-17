import SwiftUI

enum MenuBarCount {
    static func text(for count: Int?) -> String? {
        count.map { String(max($0, 0)) }
    }
}

extension AppBoot {
    @MainActor
    var menuBarCount: Int? {
        switch self {
        case let .ready(store, _, _, _): store.openCount(in: .today)
        case .failed: nil
        }
    }
}

extension AppBoot {
    @MainActor
    var menuBarTitle: String? {
        switch self {
        case let .ready(store, _, _, _): store.menuBarTitle
        case .failed: nil
        }
    }
}

struct MenuBarLabel: View {
    let count: Int?
    var title: String?

    var body: some View {
        HStack(spacing: Theme.MenuBar.spacing) {
            Image(nsImage: MenuBarIcon.makeImage())
                .renderingMode(.template)
            if let text = MenuBarCount.text(for: count) {
                Text(text)
                    .font(Theme.MenuBar.font)
            }
            if let text = MenuBarTitle.text(for: title) {
                Text(text)
                    .font(Theme.MenuBar.titleFont)
                    .lineLimit(1)
            }
        }
    }
}

struct MenuBarLabelHost: View {
    let boot: AppBoot

    var body: some View {
        MenuBarLabel(count: boot.menuBarCount, title: boot.menuBarTitle)
    }
}
