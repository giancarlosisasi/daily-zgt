import AppKit
import SwiftUI

struct PriorityDetailNoteSection: View {
    let priority: Priority

    @Environment(AppStore.self) private var store

    var body: some View {
        PriorityNoteEditor(store: store, priorityID: priority.id)
            .id(priority.id)
    }
}

private struct PriorityNoteEditor: View {
    @State private var model: PriorityNoteModel
    @Environment(\.panelLayout) private var layout
    private let images: NoteImageStore

    init(store: AppStore, priorityID: Priority.ID) {
        _model = State(initialValue: PriorityNoteModel(store: store, priorityID: priorityID))
        images = store.images
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Detail.sectionSpacing) {
            DetailSectionTitle(text: "Notas")
            RichNoteField(
                text: Binding(get: { model.text }, set: { model.edit($0) }),
                documentID: "priority-\(model.priorityID)",
                placeholder: "Contexto, links, lo que falta",
                images: images,
                style: .of(layout)
            )
            if model.writeFailed {
                Text("No se pudo guardar la nota.")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Text.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: model.externalNote) { model.sync() }
        .onDisappear { model.flush() }
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
}
