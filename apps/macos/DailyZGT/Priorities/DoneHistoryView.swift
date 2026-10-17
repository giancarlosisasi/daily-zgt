import SwiftUI

enum HistoryCopy {
    static let title = "Historial"
    static let back = "Volver a Hechas"
    static let empty = "Nada en el historial."
}

struct HistoryHeader: View {
    let listTitle: String
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: Theme.Detail.backSpacing) {
                    IconView(icon: .caretLeft, size: Theme.Detail.backChevronSize)
                    Text(HistoryCopy.title)
                        .font(Theme.Font.body)
                }
                .foregroundStyle(Theme.Detail.backText)
                .padding(.leading, Theme.Detail.backLeadingPadding)
                .padding(.trailing, Theme.Detail.backTrailingPadding)
                .frame(height: Theme.Detail.backHeight)
            }
            .buttonStyle(GhostButtonStyle(radius: Theme.Detail.backRadius))
            .accessibilityLabel(HistoryCopy.back)
            Spacer(minLength: 0)
            Text(listTitle)
                .font(Theme.History.titleFont)
                .foregroundStyle(Theme.History.titleText)
        }
    }
}

struct DoneHistoryView: View {
    let list: PriorityList

    @Environment(AppStore.self) private var store
    @Environment(PanelState.self) private var panel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Detail.spacing) {
            HistoryHeader(listTitle: list.title, onBack: { panel.closeHistory() })
            TimelineView(.everyMinute) { _ in
                DoneHistoryContent(list: list, now: store.now())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DoneHistoryContent: View {
    let list: PriorityList
    let now: Date

    @Environment(AppStore.self) private var store
    @Environment(PanelState.self) private var panel

    var body: some View {
        let cutoff = DoneWindow.cutoff(now: now)
        let groups = DoneHistory.groups(from: (try? store.donePriorities(in: list, atOrBefore: cutoff)) ?? [])
        if groups.isEmpty {
            Text(HistoryCopy.empty)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.History.emptyText)
                .padding(.vertical, Theme.History.emptyVerticalPadding)
                .padding(.horizontal, Theme.History.emptyHorizontalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.History.daySpacing) {
                    ForEach(groups) { group in
                        day(group)
                    }
                }
            }
            .frame(maxHeight: Theme.Row.listMaxHeight)
        }
    }

    private func day(_ group: DoneDayGroup) -> some View {
        VStack(alignment: .leading, spacing: Theme.History.dayRowSpacing) {
            Text(PanelLabels.historyDay(for: group.date, now: now))
                .font(Theme.History.dayFont)
                .foregroundStyle(Theme.History.dayText)
                .padding(.horizontal, Theme.History.dayPadding)
                .accessibilityAddTraits(.isHeader)
            ForEach(group.priorities) { priority in
                DoneRow(
                    priority: priority,
                    leadingPadding: Theme.History.doneRowLeadingPadding,
                    onRestore: { panel.priorityFlow.restore(priority.id) },
                    onRemove: { panel.priorityFlow.delete(priority.id) }
                )
            }
        }
    }
}
