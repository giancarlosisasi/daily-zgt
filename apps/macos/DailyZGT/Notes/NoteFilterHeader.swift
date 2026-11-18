import SwiftUI

struct NoteFilterHeader: View {
    @Environment(AppStore.self) private var store
    @Environment(PanelState.self) private var state

    var body: some View {
        TimelineView(.everyMinute) { _ in
            content(store.dueDays)
        }
    }

    private func content(_ days: DueDays) -> some View {
        let filter = state.noteFilter
        let options = DueFilter.noteOptions(days)
        return FilterHeader(
            title: DueFilterLabels.title(filter, days),
            subtitle: NoteFilterLabels.subtitle(filter, days, count: store.notes(in: filter, days: days).count),
            showsSteps: filter.isSingleDay,
            canStepForward: filter.noteStepped(by: 1, days) != nil,
            onStep: { state.stepNotes(by: $0) }
        ) { close in
            DueFilterPopover(
                selection: filter,
                days: days,
                counts: Dictionary(uniqueKeysWithValues: options.map { ($0, store.notes(in: $0, days: days).count) }),
                options: options,
                optionTitle: { NoteFilterLabels.option($0, days) },
                onSelect: { state.select(noteFilter: $0) },
                onClose: close
            )
        }
    }
}
