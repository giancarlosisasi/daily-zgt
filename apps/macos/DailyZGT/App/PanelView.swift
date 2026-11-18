import SwiftUI

extension View {
    func panelChrome(padding: CGFloat = Theme.Panel.padding) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Panel.cornerRadius, style: .continuous)
        return self
            .font(Theme.Font.body)
            .foregroundStyle(Theme.Text.primary)
            .padding(padding)
            .frame(width: Theme.Panel.width)
            .background(Theme.Panel.background, in: shape)
            .overlay(shape.strokeBorder(Theme.Panel.border, lineWidth: Theme.Panel.borderWidth))
            .background(shape.fill(Theme.Panel.side).offset(y: Theme.Panel.sideHeight))
            .padding(.bottom, Theme.Panel.sideHeight)
    }
}

struct PanelFooterBar: View {
    let now: Date

    @Environment(AppStore.self) private var store
    @Environment(PanelState.self) private var state
    @Environment(AlertCoordinator.self) private var alerts: AlertCoordinator?
    @Environment(\.panelLayout) private var layout

    var body: some View {
        PanelFooter(summary: PanelLabels.summary(for: state.filter, store: store, now: now), actions: {
            if layout == .panel {
                OpenWindowButton {
                    MainWindowController.shared.show(store: store, alerts: alerts, panel: state)
                }
            }
            TestAlertButton(alertsOff: alerts?.alertsAreOff ?? false) {
                alerts?.bellWasPressed()
            }
            SettingsButton(isOpen: state.isSettingsOpen) {
                state.toggleSettings()
            }
        })
    }
}

struct BrowseHeader: View {
    @Environment(PanelState.self) private var state

    var body: some View {
        switch state.tab {
        case .priorities:
            DueFilterHeader()
        case .notes:
            NoteFilterHeader()
        }
    }
}

struct PanelView: View {
    @Environment(AppStore.self) private var store
    @Environment(PanelState.self) private var state

    var body: some View {
        VStack(spacing: Theme.Panel.spacing) {
            switch state.page {
            case .settings:
                SettingsView()
            case .history:
                DoneHistoryView(filter: state.filter)
            case .browse:
                browse
            }
            TimelineView(.everyMinute) { _ in
                PanelFooterBar(now: store.now())
            }
        }
        .panelChrome()
        .onChange(of: state.detailPriority == nil) { state.closeDetailIfGone() }
        .onChange(of: state.detailNote == nil) { state.closeNoteIfGone() }
    }

    private var browse: some View {
        VStack(spacing: Theme.Panel.spacing) {
            SegmentedTabs(
                style: .top,
                options: [
                    .init(value: PanelTab.priorities, title: "Prioridades"),
                    .init(value: PanelTab.notes, title: "Notas"),
                ],
                selection: Binding(get: { state.tab }, set: { state.select(tab: $0) })
            )
            if state.detailPriority == nil && state.detailNote == nil {
                BrowseHeader()
            }
            content
        }
    }

    private var content: some View {
        VStack(spacing: Theme.Panel.spacing) {
            ForEach(PanelContentSlot.order(for: state.tab), id: \.self) { slot in
                switch slot {
                case .main:
                    tabContent
                case .undoBar:
                    undoBar
                }
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch state.tab {
        case .priorities:
            prioritiesContent
        case .notes:
            if let note = state.detailNote {
                NoteDetailView(note: note)
            } else {
                NoteListView(filter: state.noteFilter)
            }
        }
    }

    private var prioritiesContent: some View {
        VStack(spacing: 0) {
            if let priority = state.detailPriority {
                PriorityDetailView(priority: priority)
                    .id(priority.id)
            } else {
                PriorityListView(filter: state.filter)
            }
        }
    }

    private var undoBar: some View {
        PanelUndoBars()
    }
}

struct PanelUndoBars: View {
    @Environment(PanelState.self) private var state

    var body: some View {
        let flow = state.priorityFlow
        let notes = state.noteFlow
        if let undo = notes.undo {
            TimedUndoBar(undo: undo, prefix: NoteFilterLabels.deleted, icon: .trash, onUndo: { notes.undoDelete() })
        }
        if let undo = flow.undo {
            TimedUndoBar(undo: undo, onUndo: { flow.undoDone() })
        }
    }
}
