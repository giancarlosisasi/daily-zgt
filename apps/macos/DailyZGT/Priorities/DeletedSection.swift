import SwiftUI

struct DeletedEntry: Equatable, Identifiable {
    let id: String
    let title: String
    let deletedAt: Date

    init(_ priority: Priority) {
        id = priority.id
        title = priority.title
        deletedAt = priority.deletedAt ?? priority.updatedAt
    }

    init(_ note: NoteItem) {
        id = note.id
        title = NoteSummary.make(note.body).title
        deletedAt = note.deletedAt ?? note.updatedAt
    }
}

enum DeletedCopy {
    static let headerTitle = "Eliminadas"
    static let confirmTitle = "¿Borrar para siempre?"
    static let confirmHint = "No se puede deshacer."
    static let confirmButton = "Borrar"
}

struct DeletedSection: View {
    let entries: [DeletedEntry]
    let onOpen: (String) -> Void
    let onRestore: (String) -> Void
    let onDeleteForever: (String) -> Void

    @Environment(AppStore.self) private var store
    @Environment(PanelState.self) private var panel
    @Environment(\.panelLayout) private var layout
    @State private var confirmingID: String?

    init(
        entries: [DeletedEntry],
        confirmingAtStart: String? = nil,
        onOpen: @escaping (String) -> Void = { _ in },
        onRestore: @escaping (String) -> Void = { _ in },
        onDeleteForever: @escaping (String) -> Void = { _ in }
    ) {
        self.entries = entries
        self.onOpen = onOpen
        self.onRestore = onRestore
        self.onDeleteForever = onDeleteForever
        _confirmingID = State(initialValue: confirmingAtStart)
    }

    var body: some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: Theme.DoneSection.spacing) {
                SectionToggleHeader(
                    title: DeletedCopy.headerTitle,
                    count: entries.count,
                    isOpen: panel.isDeletedOpen,
                    onToggle: { panel.toggleDeleted() }
                )
                if panel.isDeletedOpen {
                    TimelineView(.everyMinute) { _ in
                        rows(DueDays(now: store.now()))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Theme.Space.group(layout))
        }
    }

    @ViewBuilder
    private func rows(_ days: DueDays) -> some View {
        switch layout {
        case .panel:
            ScrollView {
                stack(days)
            }
            .frame(maxHeight: Theme.Row.listMaxHeight)
        case .window:
            stack(days)
        }
    }

    private func stack(_ days: DueDays) -> some View {
        VStack(alignment: .leading, spacing: Theme.DoneSection.spacing) {
            ForEach(entries) { entry in
                VStack(spacing: 0) {
                    DoneRow(
                        title: entry.title,
                        kind: .deleted,
                        doneTime: NoteFilterLabels.rowDate(entry.deletedAt, days),
                        onOpen: { onOpen(entry.id) },
                        onRestore: {
                            confirmingID = nil
                            onRestore(entry.id)
                        },
                        onRemove: { confirmingID = confirmingID == entry.id ? nil : entry.id }
                    )
                    if confirmingID == entry.id {
                        DoneConfirmationBar(
                            title: DeletedCopy.confirmTitle,
                            openSubtasksLabel: DeletedCopy.confirmHint,
                            confirmIcon: .trash,
                            confirmTitle: DeletedCopy.confirmButton,
                            onCancel: { confirmingID = nil },
                            onConfirm: {
                                confirmingID = nil
                                onDeleteForever(entry.id)
                            }
                        )
                    }
                }
            }
        }
    }
}
