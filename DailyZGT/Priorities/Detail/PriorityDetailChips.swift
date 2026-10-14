import SwiftUI

struct PriorityDetailChips: View {
    let priority: Priority
    let progress: SubtaskProgress
    let now: Date
    var todayChip: DueChipState?

    var body: some View {
        HStack(spacing: Theme.Detail.chipSpacing) {
            Text(PriorityDetailLabels.state(of: priority))
                .font(Theme.Detail.chipFont)
                .foregroundStyle(priority.isDone ? Theme.Detail.doneStateText : Theme.Detail.stateText)
                .padding(.horizontal, Theme.Detail.chipHorizontalPadding)
                .padding(.vertical, Theme.Detail.chipVerticalPadding)
                .background(
                    priority.isDone ? Theme.Detail.doneStateBackground : Theme.Detail.stateBackground,
                    in: RoundedRectangle(cornerRadius: Theme.Detail.chipRadius, style: .continuous)
                )
            if !priority.isDone, let due = DueChipState.make(due: priority.dueAt, now: now) {
                DueChip(state: due, horizontalPadding: Theme.Detail.chipHorizontalPadding)
            }
            if !priority.isDone, let todayChip {
                DueChip(state: todayChip, horizontalPadding: Theme.Detail.chipHorizontalPadding)
            }
            if let label = PriorityDetailLabels.subtasks(progress) {
                Text(label)
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Text.muted)
            }
            Spacer(minLength: 0)
        }
    }
}
