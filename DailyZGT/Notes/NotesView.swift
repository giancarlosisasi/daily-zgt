import AppKit
import SwiftUI

struct NotesView: View {
    let scope: NoteScope

    @Environment(AppStore.self) private var store

    var body: some View {
        NotesEditor(store: store, scope: scope)
    }
}

private struct NotesEditor: View {
    let scope: NoteScope

    @State private var model: NotesModel

    init(store: AppStore, scope: NoteScope) {
        self.scope = scope
        _model = State(initialValue: NotesModel(store: store, scope: scope))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Notes.spacing) {
            Text(scope == .day ? "Notas de hoy" : "Notas de la semana")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Text.muted)
            textArea
            Text(model.writeFailed ? "No se pudo guardar la nota." : "Se guarda al escribir.")
                .font(Theme.Font.meta)
                .foregroundStyle(Theme.Notes.hint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: scope) { _, newScope in model.select(scope: newScope) }
        .onChange(of: model.externalBody) { model.sync() }
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
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: Theme.Notes.syncInterval)
                model.sync()
            }
        }
    }

    private var textArea: some View {
        NoteTextArea(
            text: Binding(get: { model.text }, set: { model.edit($0) }),
            placeholder: "Escribe una nota"
        )
    }
}
