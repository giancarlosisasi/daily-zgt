import SwiftUI

enum PanelLayout: Sendable {
    case panel
    case window
}

private struct PanelLayoutKey: EnvironmentKey {
    static let defaultValue = PanelLayout.panel
}

extension EnvironmentValues {
    var panelLayout: PanelLayout {
        get { self[PanelLayoutKey.self] }
        set { self[PanelLayoutKey.self] = newValue }
    }
}
