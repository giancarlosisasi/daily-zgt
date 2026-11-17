import AppKit
import SwiftUI

struct MainWindowView: View {
    static let title = title(isDebugBuild: AppDatabase.isDebugBuild)

    static func title(isDebugBuild: Bool) -> String {
        isDebugBuild ? "Daily ZGT Dev" : "Daily ZGT"
    }
    static let emptyDetail = "Elige una prioridad para ver su detalle."

    @Environment(AppStore.self) private var store
    @Environment(PanelState.self) private var state
    @AppStorage private var sidebarWidth: Double
    @State private var dragStartWidth: Double?

    init(defaults: UserDefaults = .standard) {
        _sidebarWidth = AppStorage(
            wrappedValue: Double(Theme.Window.sidebarIdeal),
            Theme.Window.sidebarWidthKey,
            store: defaults
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: Theme.Window.clampedSidebar(sidebarWidth))
            divider
            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .font(Theme.Font.body)
        .foregroundStyle(Theme.Text.primary)
        .frame(minWidth: Theme.Window.minWidth, minHeight: Theme.Window.minHeight)
        .background(Theme.Panel.background)
        .environment(\.panelLayout, .window)
        .onChange(of: state.detailPriority == nil) { state.closeDetailIfGone() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: Theme.Panel.spacing) {
            SegmentedTabs(
                style: .top,
                options: [
                    .init(value: PanelTab.priorities, title: "Prioridades"),
                    .init(value: PanelTab.notes, title: "Notas"),
                ],
                selection: Binding(get: { state.tab }, set: { state.select(tab: $0) })
            )
            BrowseHeader()
            switch state.tab {
            case .priorities:
                ScrollView {
                    PriorityListView(filter: state.filter)
                }
                .scrollIndicators(.automatic)
            case .notes:
                Spacer(minLength: 0)
            }
            undoBar
            TimelineView(.everyMinute) { _ in
                PanelFooterBar(now: store.now())
            }
        }
        .padding(.horizontal, Theme.Window.sidebarPadding)
        .padding(.top, Theme.Window.sidebarTopPadding)
        .padding(.bottom, Theme.Window.sidebarPadding)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.Window.sidebarBackground)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.Window.divider)
            .frame(width: Theme.Window.dividerWidth)
            .overlay {
                Color.clear
                    .frame(width: Theme.Window.dividerGrabWidth)
                    .contentShape(Rectangle())
                    .onHover { inside in
                        if inside {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .global)
                            .onChanged { value in
                                let start = dragStartWidth ?? Theme.Window.clampedSidebar(sidebarWidth)
                                dragStartWidth = start
                                sidebarWidth = Theme.Window.clampedSidebar(start + value.translation.width)
                            }
                            .onEnded { _ in dragStartWidth = nil }
                    )
                    .accessibilityHidden(true)
            }
    }

    @ViewBuilder
    private var detailPane: some View {
        switch state.page {
        case .settings:
            ScrollView {
                SettingsView()
                    .readableColumn()
            }
        case .history:
            DoneHistoryView(filter: state.filter)
        case .browse:
            switch state.tab {
            case .priorities:
                if let priority = state.detailPriority {
                    ScrollView {
                        PriorityDetailView(priority: priority)
                            .id(priority.id)
                            .readableColumn()
                    }
                } else {
                    Text(Self.emptyDetail)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.EmptyList.text)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .notes:
                ScrollView {
                    NotesView(scope: state.noteScope)
                        .readableColumn()
                }
            }
        }
    }

    @ViewBuilder
    private var undoBar: some View {
        let flow = state.priorityFlow
        if let undo = flow.undo {
            TimedUndoBar(undo: undo, onUndo: { flow.undoDone() })
        }
    }
}
