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

    var body: some View {
        PanelFooter(summary: PanelLabels.summary(for: state.scope, store: store, now: now), actions: {
            TestAlertButton(alertsOff: alerts?.alertsAreOff ?? false) {
                alerts?.bellWasPressed()
            }
            SettingsButton(isOpen: state.isSettingsOpen) {
                state.toggleSettings()
            }
        })
    }
}

struct PanelView: View {
    @Environment(AppStore.self) private var store
    @Environment(PanelState.self) private var state

    var body: some View {
        VStack(spacing: Theme.Panel.spacing) {
            Group {
                switch state.page {
                case .settings:
                    SettingsView()
                        .motionTransition(.slideIn)
                case .history:
                    DoneHistoryView(list: state.scope)
                        .motionTransition(.slideIn)
                case .browse:
                    browse
                        .motionTransition(.slideBack)
                }
            }
            .motion(.slide, value: state.page)
            TimelineView(.everyMinute) { _ in
                PanelFooterBar(now: store.now())
            }
        }
        .panelChrome()
        .onChange(of: state.detailPriority == nil) { state.closeDetailIfGone() }
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
            if state.detailPriority == nil {
                scopeRow
            }
            content
        }
    }

    private var scopeRow: some View {
        HStack(spacing: 8) {
            SegmentedTabs(
                style: .scope,
                options: [
                    .init(value: PriorityList.today, title: "Hoy · \(store.openCount(in: .today))"),
                    .init(value: PriorityList.week, title: "Semana · \(store.openCount(in: .week))"),
                ],
                selection: Binding(get: { state.scope }, set: { state.select(scope: $0) })
            )
            Spacer(minLength: 0)
            Text(PanelLabels.date(for: state.scope, at: store.now()))
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Text.muted)
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
        .motion(.fade, value: state.tab)
        .motion(.rowIn, value: state.priorityFlow.undo?.token)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch state.tab {
        case .priorities:
            prioritiesContent
                .motionTransition(.fadeIn)
        case .notes:
            NotesView(scope: state.scope.noteScope)
                .motionTransition(.fadeIn)
        }
    }

    private var prioritiesContent: some View {
        VStack(spacing: 0) {
            if let priority = state.detailPriority {
                PriorityDetailView(priority: priority)
                    .id(priority.id)
                    .motionTransition(.slideIn)
            } else {
                PriorityListView(list: state.scope)
                    .motionTransition(.slideBack)
            }
        }
        .motion(.slide, value: state.detailPriority?.id)
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
