import SwiftUI

struct DetailBackButton: View {
    let title: String
    var accessibilityTitle: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Detail.backSpacing) {
                IconView(icon: .caretLeft, size: Theme.Detail.backChevronSize)
                Text(title)
                    .font(Theme.Font.body)
            }
            .foregroundStyle(Theme.Detail.backText)
            .padding(.leading, Theme.Detail.backLeadingPadding)
            .padding(.trailing, Theme.Detail.backTrailingPadding)
            .frame(height: Theme.Detail.backHeight)
        }
        .buttonStyle(GhostButtonStyle(radius: Theme.Detail.backRadius))
        .accessibilityLabel(accessibilityTitle ?? "Volver a \(title)")
        .padding(.leading, -Theme.Detail.backLeadingPadding)
    }
}

struct PriorityDetailHeader<Title: View>: View {
    let backLabel: String
    var deleteLabel = "Eliminar prioridad"
    let onBack: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let title: Title

    @Environment(\.panelLayout) private var layout

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Detail.headSpacing) {
            if layout == .panel {
                DetailBackButton(title: backLabel, action: onBack)
            }
            HStack(alignment: .top, spacing: Theme.Detail.headSpacing) {
                title
                    .frame(maxWidth: .infinity, alignment: .leading)
                RowIconButton(
                    icon: .trash,
                    size: Theme.Detail.deleteIconSize,
                    width: Theme.Detail.deleteSize,
                    height: Theme.Detail.deleteSize,
                    radius: Theme.Detail.deleteRadius,
                    label: deleteLabel,
                    action: onDelete
                )
            }
        }
    }
}
