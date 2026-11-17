import SwiftUI

enum HistoryCopy {
    static let title = "Historial"
    static let back = "Prioridades"
    static let backLabel = "Volver a Prioridades"
    static let empty = "Nada en el historial."

    static func count(_ count: Int) -> String {
        count == 1 ? "1 hecha" : "\(count) hechas"
    }

    static func time(of date: Date?, calendar: Calendar = .current) -> String? {
        guard let date else { return nil }
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
}

struct HistoryHeader: View {
    let onBack: () -> Void

    @Environment(\.panelLayout) private var layout

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.History.backTitleSpacing) {
            if layout == .panel {
                DetailBackButton(title: HistoryCopy.back, accessibilityTitle: HistoryCopy.backLabel, action: onBack)
            }
            Text(HistoryCopy.title)
                .font(layout == .window ? Theme.Detail.windowTitleFont : Theme.Detail.titleFont)
                .foregroundStyle(Theme.Text.strong)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DoneHistoryView: View {
    let filter: DueFilter

    @Environment(AppStore.self) private var store
    @Environment(PanelState.self) private var panel
    @Environment(\.panelLayout) private var layout

    var body: some View {
        switch layout {
        case .window:
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HistoryHeader(onBack: { panel.closeHistory() })
                    content
                }
                .readableColumn()
            }
        case .panel:
            VStack(alignment: .leading, spacing: 0) {
                HistoryHeader(onBack: { panel.closeHistory() })
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var content: some View {
        TimelineView(.everyMinute) { _ in
            DoneHistoryContent(filter: filter, now: store.now())
        }
    }
}

struct DoneHistoryContent: View {
    let filter: DueFilter
    let now: Date

    @Environment(AppStore.self) private var store
    @Environment(PanelState.self) private var panel
    @Environment(\.panelLayout) private var layout

    var body: some View {
        let groups = DoneHistory.groups(from: store.olderDonePriorities(outside: filter, days: DueDays(now: now)))
        if groups.isEmpty {
            Text(HistoryCopy.empty)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.History.emptyText)
                .padding(.top, Theme.Space.group(layout))
                .padding(.horizontal, Theme.History.emptyHorizontalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            switch layout {
            case .window:
                days(groups)
            case .panel:
                ScrollView {
                    days(groups)
                }
                .frame(maxHeight: Theme.Row.listMaxHeight)
            }
        }
    }

    private func days(_ groups: [DoneDayGroup]) -> some View {
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
            ForEach(groups) { group in
                Section {
                    ForEach(group.priorities) { priority in
                        DoneRow(
                            priority: priority,
                            leadingPadding: Theme.History.rowLeadingPadding,
                            look: .history,
                            doneTime: HistoryCopy.time(of: priority.doneAt),
                            onOpen: { panel.openDetail(priority.id) },
                            onRestore: { panel.priorityFlow.restore(priority.id) },
                            onRemove: { panel.priorityFlow.delete(priority.id) }
                        )
                    }
                } header: {
                    dayHeader(group)
                }
            }
        }
    }

    private func dayHeader(_ group: DoneDayGroup) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(PanelLabels.historyDay(for: group.date, now: now))
                .font(Theme.History.dayFont)
                .foregroundStyle(Theme.History.dayText)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Text(HistoryCopy.count(group.priorities.count))
                .font(Theme.History.countFont)
                .foregroundStyle(Theme.History.countText)
        }
        .padding(.horizontal, Theme.History.dayHorizontalPadding)
        .padding(.top, Theme.Space.group(layout))
        .padding(.bottom, Theme.History.dayBottomPadding)
        .background(Theme.History.headerBackground)
    }
}

extension View {
    func readableColumn() -> some View {
        frame(maxWidth: Theme.Window.readableWidth, alignment: .leading)
            .padding(.horizontal, Theme.Window.detailGutter)
            .padding(.top, Theme.Window.detailTopPadding)
            .padding(.bottom, Theme.Window.detailBottomPadding)
            .frame(maxWidth: .infinity)
    }
}
