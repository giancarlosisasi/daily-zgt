import SwiftUI

struct NoteListView: View {
    let filter: DueFilter

    @Environment(AppStore.self) private var store
    @Environment(PanelState.self) private var panel
    @Environment(\.panelLayout) private var layout

    var body: some View {
        VStack(spacing: 0) {
            NewPriorityButton(title: NoteFilterLabels.newNote) { panel.createNote() }
                .keyboardShortcut("n", modifiers: .command)
            TimelineView(.everyMinute) { _ in
                let days = store.dueDays
                let notes = store.notes(in: filter, days: days)
                if notes.isEmpty {
                    Text(NoteFilterLabels.empty(filter, days))
                        .font(Theme.Filter.emptyFont)
                        .foregroundStyle(Theme.Filter.emptyText)
                        .padding(.top, Theme.Filter.emptyTopPadding)
                        .padding(.bottom, Theme.Filter.emptyBottomPadding)
                        .padding(.horizontal, Theme.Filter.emptyHorizontalPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    rows(notes, days: days)
                }
            }
            if panel.noteFlow.writeFailed || panel.saveError != nil {
                Text("No se pudo guardar el cambio.")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Text.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .transaction(value: filter) { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    @ViewBuilder
    private func rows(_ notes: [NoteItem], days: DueDays) -> some View {
        switch layout {
        case .panel:
            ScrollView {
                stack(notes, days: days)
            }
            .frame(maxHeight: Theme.Row.listMaxHeight)
        case .window:
            stack(notes, days: days)
        }
    }

    private func stack(_ notes: [NoteItem], days: DueDays) -> some View {
        VStack(spacing: Theme.Row.listSpacing) {
            ForEach(notes) { note in
                NoteRow(
                    note: note,
                    days: days,
                    isSelected: panel.openNoteID == note.id,
                    onOpen: { panel.openNote(note.id) },
                    onRemove: { panel.deleteNote(note.id) }
                )
            }
        }
    }
}
