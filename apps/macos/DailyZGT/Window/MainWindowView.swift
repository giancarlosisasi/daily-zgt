import SwiftUI

struct MainWindowView: View {
    static let title = "Daily ZGT"
    static let emptyDetail = "Elige una prioridad para ver su detalle."

    @Environment(AppStore.self) private var store
    @Environment(PanelState.self) private var state

    var body: some View {
        VStack(spacing: Theme.Panel.spacing) {
            Group {
                switch state.page {
                case .settings:
                    ScrollView {
                        SettingsView()
                            .frame(maxWidth: Theme.Window.pageMaxWidth)
                    }
                    .motionTransition(.slideIn)
                case .history:
                    DoneHistoryView(list: state.scope)
                        .frame(maxWidth: Theme.Window.pageMaxWidth)
                        .motionTransition(.slideIn)
                case .browse:
                    browse
                        .motionTransition(.slideBack)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .motion(.slide, value: state.page)
            TimelineView(.everyMinute) { _ in
                PanelFooterBar(now: store.now())
            }
        }
        .font(Theme.Font.body)
        .foregroundStyle(Theme.Text.primary)
        .padding(Theme.Window.padding)
        .frame(minWidth: Theme.Window.minWidth, minHeight: Theme.Window.minHeight)
        .background(Theme.Panel.background)
        .environment(\.panelLayout, .window)
        .onChange(of: state.detailPriority == nil) { state.closeDetailIfGone() }
    }

    private var browse: some View {
        VStack(alignment: .leading, spacing: Theme.Panel.spacing) {
            SegmentedTabs(
                style: .top,
                options: [
                    .init(value: PanelTab.priorities, title: "Prioridades"),
                    .init(value: PanelTab.notes, title: "Notas"),
                ],
                selection: Binding(get: { state.tab }, set: { state.select(tab: $0) })
            )
            .frame(width: Theme.Window.listWidth)
            switch state.tab {
            case .priorities:
                HStack(alignment: .top, spacing: Theme.Window.columnSpacing) {
                    listColumn
                        .frame(width: Theme.Window.listWidth)
                    Rectangle()
                        .fill(Theme.Window.divider)
                        .frame(width: Theme.Window.dividerWidth)
                    detailColumn
                }
                .motionTransition(.fadeIn)
            case .notes:
                VStack(spacing: Theme.Panel.spacing) {
                    ScopeRow()
                        .frame(width: Theme.Window.listWidth)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    undoBar
                    NotesView(scope: state.scope.noteScope)
                }
                .motionTransition(.fadeIn)
            }
        }
        .motion(.fade, value: state.tab)
    }

    private var listColumn: some View {
        VStack(spacing: Theme.Panel.spacing) {
            ScopeRow()
            ScrollView {
                PriorityListView(list: state.scope)
            }
            undoBar
        }
        .motion(.rowIn, value: state.priorityFlow.undo?.token)
    }

    private var detailColumn: some View {
        Group {
            if let priority = state.detailPriority {
                ScrollView {
                    PriorityDetailView(priority: priority)
                        .id(priority.id)
                        .frame(maxWidth: Theme.Window.detailMaxWidth, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .motionTransition(.fadeIn)
            } else {
                Text(Self.emptyDetail)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.EmptyList.text)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .motionTransition(.fadeIn)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .motion(.fade, value: state.detailPriority?.id)
    }

    @ViewBuilder
    private var undoBar: some View {
        let flow = state.priorityFlow
        if let undo = flow.undo {
            TimedUndoBar(undo: undo, onUndo: { flow.undoDone() })
                .motionTransition(.rowIn)
        }
    }
}
