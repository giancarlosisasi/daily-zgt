enum PanelPage: CaseIterable, Hashable, Sendable {
    case browse
    case settings
    case history
}

enum PanelContentSlot: CaseIterable, Hashable, Sendable {
    case main
    case undoBar

    static func order(for tab: PanelTab) -> [PanelContentSlot] {
        switch tab {
        case .priorities: [.main, .undoBar]
        case .notes: [.undoBar, .main]
        }
    }
}
