import AppKit
import SwiftUI

struct TestAlertButton: View {
    var alertsOff = false
    let action: () -> Void

    @State private var ringCount = 0

    var body: some View {
        Button(action: press) {
            IconView(icon: alertsOff ? .bellSlash : .bell, size: Theme.Footer.iconSize)
                .foregroundStyle(Theme.Footer.bellText)
                .bellRing(trigger: ringCount)
                .frame(width: Theme.Footer.iconButtonWidth, height: Theme.Ghost.height)
        }
        .buttonStyle(.ghost)
        .accessibilityLabel(AlertCopy.test)
        .help(alertsOff ? AlertCopy.off : AlertCopy.test)
    }

    private func press() {
        if !alertsOff {
            ringCount += 1
        }
        action()
    }
}

struct SettingsButton: View {
    var isOpen = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            IconView(icon: .gear, size: Theme.Footer.iconSize)
                .foregroundStyle(isOpen ? Theme.Footer.gearOpenText : Theme.Footer.gearText)
                .frame(width: Theme.Footer.iconButtonWidth, height: Theme.Ghost.height)
        }
        .buttonStyle(.ghost)
        .accessibilityLabel(SettingsCopy.title)
        .accessibilityAddTraits(isOpen ? .isSelected : [])
        .help(SettingsCopy.title)
    }
}

struct PanelFooter<Actions: View>: View {
    let summary: String
    let quit: () -> Void
    @ViewBuilder let actions: Actions

    init(
        summary: String,
        quit: @escaping () -> Void = { NSApplication.shared.terminate(nil) },
        @ViewBuilder actions: () -> Actions
    ) {
        self.summary = summary
        self.quit = quit
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Theme.Footer.divider)
                .frame(height: Theme.Footer.dividerHeight)
            HStack {
                Text(summary)
                    .font(Theme.Font.footer)
                    .foregroundStyle(Theme.Footer.text)
                Spacer(minLength: 0)
                HStack(spacing: Theme.Footer.actionSpacing) {
                    actions
                    Button(action: quit) {
                        Text("Salir")
                            .font(Theme.Font.footer)
                            .foregroundStyle(Theme.Footer.quitText)
                            .padding(.horizontal, Theme.Ghost.padding)
                            .frame(height: Theme.Ghost.height)
                    }
                    .buttonStyle(.ghost)
                }
            }
            .padding(.top, Theme.Footer.topPadding)
            .padding(.horizontal, Theme.Footer.horizontalPadding)
        }
    }
}

extension PanelFooter where Actions == EmptyView {
    init(summary: String, quit: @escaping () -> Void = { NSApplication.shared.terminate(nil) }) {
        self.init(summary: summary, quit: quit) { EmptyView() }
    }
}
