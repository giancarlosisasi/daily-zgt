import SwiftUI

struct NoteRow: View {
    let note: NoteItem
    let days: DueDays
    var isSelected = false
    let onOpen: () -> Void
    let onRemove: () -> Void

    @State private var isHovering: Bool
    @Environment(\.panelLayout) private var layout

    init(
        note: NoteItem,
        days: DueDays,
        isSelected: Bool = false,
        isHoveringAtStart: Bool = false,
        onOpen: @escaping () -> Void = {},
        onRemove: @escaping () -> Void = {}
    ) {
        self.note = note
        self.days = days
        self.isSelected = isSelected
        self.onOpen = onOpen
        self.onRemove = onRemove
        _isHovering = State(initialValue: isHoveringAtStart)
    }

    var body: some View {
        let summary = NoteSummary.make(note.body)
        HStack(alignment: .top, spacing: Theme.Row.spacing) {
            VStack(alignment: .leading, spacing: Theme.Row.titleSpacing) {
                Text(summary.title)
                    .font(Theme.Font.bodyStrong)
                    .foregroundStyle(NoteBody.isEmpty(note.body) ? Theme.Text.dim : Theme.Text.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let preview = summary.preview {
                    Text(preview)
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Text.muted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(NoteFilterLabels.rowDate(note.createdAt, days))
                .font(Theme.Font.meta)
                .foregroundStyle(Theme.Text.dim)
                .frame(height: Theme.Font.rowTitleLineHeight)
                .opacity(isHovering ? 0 : 1)
                .overlay(alignment: .trailing) {
                    RowIconButton(
                        icon: .trash,
                        size: Theme.Row.removeIconSize,
                        width: Theme.Row.removeSize,
                        height: Theme.Row.removeSize,
                        radius: Theme.Row.removeRadius,
                        label: NoteFilterLabels.deleteNote,
                        action: onRemove
                    )
                    .opacity(isHovering ? 1 : 0)
                }
        }
        .padding(.vertical, Theme.Row.verticalPadding)
        .padding(.horizontal, Theme.Row.horizontalPadding)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .linkCursor()
        .listRowSurface(layout: layout, isSelected: isSelected, isHovering: isHovering)
        .hoverArea { isHovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: NoteFilterLabels.deleteNote, onRemove)
    }
}
