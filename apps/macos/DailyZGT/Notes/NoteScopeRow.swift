import SwiftUI

struct NoteScopeRow: View {
    @Environment(AppStore.self) private var store
    @Environment(PanelState.self) private var state

    var body: some View {
        HStack(spacing: Theme.Space.s2) {
            SegmentedTabs(
                style: .scope,
                options: [
                    .init(value: NoteScope.day, title: "Hoy"),
                    .init(value: NoteScope.week, title: "Semana"),
                ],
                selection: Binding(get: { state.noteScope }, set: { state.select(noteScope: $0) })
            )
            Spacer(minLength: 0)
            Text(PanelLabels.date(for: state.noteScope, at: store.now()))
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Text.muted)
        }
    }
}
