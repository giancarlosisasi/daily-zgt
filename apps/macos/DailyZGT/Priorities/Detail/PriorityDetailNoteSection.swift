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

    init(store: AppStore, priorityID: Priority.ID) {
        _model = State(initialValue: PriorityNoteModel(store: store, priorityID: priorityID))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Detail.sectionSpacing) {
            DetailSectionTitle(text: "Notas")
            NoteTextArea(
                text: Binding(get: { model.text }, set: { model.edit($0) }),
                placeholder: "Contexto, links, lo que falta",
                minHeight: layout == .window ? Theme.Notes.windowMinHeight : Theme.Notes.panelMinHeight,
                maxHeight: layout == .window ? nil : Theme.Notes.panelMaxHeight
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
