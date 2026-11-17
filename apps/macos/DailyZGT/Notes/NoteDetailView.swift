import AppKit
import SwiftUI

struct NoteDetailView: View {
    let note: NoteItem

    @Environment(AppStore.self) private var store
    @Environment(PanelState.self) private var panel

    var body: some View {
        NoteEditor(store: store, note: note, focusOnAppear: panel.focusNoteID == note.id)
            .id(note.id)
    }
}

private struct NoteEditor: View {
    let note: NoteItem
    let focusOnAppear: Bool

    @State private var model: NoteBodyModel
    @Environment(AppStore.self) private var store
    @Environment(PanelState.self) private var panel
    @Environment(\.panelLayout) private var layout
    private let images: NoteImageStore

    init(store: AppStore, note: NoteItem, focusOnAppear: Bool) {
        self.note = note
        self.focusOnAppear = focusOnAppear
        _model = State(initialValue: NoteBodyModel(store: store, noteID: note.id))
        images = store.images
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.group(layout)) {
            PriorityDetailHeader(
                backLabel: DueFilterLabels.title(panel.noteFilter, store.dueDays),
                deleteLabel: NoteFilterLabels.deleteNote,
                onBack: { panel.closeNote() },
                onDelete: delete
            ) {
                TimelineView(.everyMinute) { _ in
                    Text(NoteFilterLabels.meta(note, store.dueDays))
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Detail.created)
                        .frame(minHeight: Theme.Detail.deleteSize)
                }
            }
            VStack(alignment: .leading, spacing: Theme.Notes.spacing) {
                RichNoteField(
                    text: Binding(get: { model.text }, set: { model.edit($0) }),
                    documentID: "note-\(note.id)",
                    placeholder: NoteFilterLabels.placeholder,
                    images: images,
                    style: layout == .window ? .page : .panel,
                    focusOnAppear: focusOnAppear
                )
                Text(model.writeFailed ? NoteFilterLabels.saveFailed : NoteFilterLabels.saveHint)
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Notes.hint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: model.externalBody) { model.sync() }
        .onDisappear { model.leave() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            model.sync()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            model.flush()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            model.flush()
        }
    }

    private func delete() {
        model.flush()
        panel.deleteNote(note.id)
    }
}
