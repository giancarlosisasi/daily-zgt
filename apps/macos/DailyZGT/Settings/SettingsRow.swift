import SwiftUI

struct SettingsRow<Control: View, Notes: View>: View {
    let title: String
    let detail: String
    let control: Control
    let notes: Notes

    init(
        title: String,
        detail: String,
        @ViewBuilder control: () -> Control,
        @ViewBuilder notes: () -> Notes
    ) {
        self.title = title
        self.detail = detail
        self.control = control()
        self.notes = notes()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Settings.radius, style: .continuous)
        VStack(alignment: .leading, spacing: Theme.Settings.rowSpacing) {
            HStack(alignment: .center, spacing: Theme.Settings.controlSpacing) {
                VStack(alignment: .leading, spacing: Theme.Settings.textSpacing) {
                    Text(title)
                        .font(Theme.Settings.titleFont)
                        .foregroundStyle(Theme.Settings.title)
                    Text(detail)
                        .font(Theme.Settings.detailFont)
                        .foregroundStyle(Theme.Settings.detail)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                control
            }
            notes
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Settings.rowPadding)
        .background(Theme.Settings.background, in: shape)
        .overlay(shape.strokeBorder(Theme.Settings.border, lineWidth: 1))
    }
}

extension SettingsRow where Notes == EmptyView {
    init(title: String, detail: String, @ViewBuilder control: () -> Control) {
        self.init(title: title, detail: detail, control: control, notes: { EmptyView() })
    }
}

struct SettingsNote: View {
    let text: String
    var linkTitle: String?
    var onLink: () -> Void = {}

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Settings.noteSpacing) {
                message
                link
            }
            VStack(alignment: .leading, spacing: Theme.AlertsOff.stackedSpacing) {
                message
                link
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var message: some View {
        Text(text)
            .font(Theme.Settings.noteFont)
            .foregroundStyle(Theme.Settings.note)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var link: some View {
        if let linkTitle {
            Button(action: onLink) {
                Text(linkTitle)
                    .font(Theme.Settings.linkFont)
                    .foregroundStyle(Theme.Settings.link)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
        }
    }
}
