import AppKit
import SwiftUI

enum NotificationSettings {
    static let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!

    @MainActor
    @discardableResult
    static func open(using opener: (URL) -> Bool = { NSWorkspace.shared.open($0) }) -> Bool {
        opener(url)
    }
}

struct AlertsOffNotice: View {
    var onOpenSettings: () -> Void = { NotificationSettings.open() }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.AlertsOff.spacing) {
                message
                button
            }
            VStack(alignment: .leading, spacing: Theme.AlertsOff.stackedSpacing) {
                message
                button
            }
        }
    }

    private var message: some View {
        Text(AlertCopy.off)
            .lineLimit(1)
    }

    private var button: some View {
        Button(action: onOpenSettings) {
            Text(AlertCopy.openSettings)
                .font(Theme.AlertsOff.linkFont)
                .foregroundStyle(Theme.AlertsOff.link)
                .lineLimit(1)
        }
        .buttonStyle(.plain)
    }
}
