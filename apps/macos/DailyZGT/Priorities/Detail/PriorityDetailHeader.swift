import SwiftUI

struct PriorityDetailHeader: View {
    let backLabel: String
    let onBack: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: Theme.Detail.backSpacing) {
                    IconView(icon: .caretLeft, size: Theme.Detail.backChevronSize)
                    Text(backLabel)
                        .font(Theme.Font.body)
                }
                .foregroundStyle(Theme.Detail.backText)
                .padding(.leading, Theme.Detail.backLeadingPadding)
                .padding(.trailing, Theme.Detail.backTrailingPadding)
                .frame(height: Theme.Detail.backHeight)
            }
            .buttonStyle(GhostButtonStyle(radius: Theme.Detail.backRadius))
            .accessibilityLabel("Volver a \(backLabel)")
            Spacer(minLength: 0)
            RowIconButton(
                icon: .trash,
                size: Theme.Detail.deleteIconSize,
                width: Theme.Detail.deleteSize,
                height: Theme.Detail.deleteSize,
                radius: Theme.Detail.deleteRadius,
                label: "Eliminar prioridad",
                action: onDelete
            )
        }
    }
}
