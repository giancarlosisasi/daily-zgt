import SwiftUI

struct PriorityDetailChips: View {
    let priority: Priority
    let progress: SubtaskProgress
    let now: Date
    var todayChip: DueChipState?

    static func showsAny(priority: Priority, now: Date, todayChip: DueChipState?) -> Bool {
        priority.isDone || overdue(priority: priority, now: now) != nil || todayChip != nil
    }

    static func overdue(priority: Priority, now: Date) -> DueChipState? {
        guard !priority.isDone, let due = DueChipState.make(due: priority.dueAt, now: now), due.tone == .overdue else {
            return nil
        }
        return due
    }

    var body: some View {
        HStack(spacing: Theme.Detail.chipSpacing) {
            if priority.isDone {
                Text(PriorityDetailLabels.state(of: priority))
                    .font(Theme.Detail.chipFont)
                    .foregroundStyle(Theme.Detail.doneStateText)
                    .padding(.horizontal, Theme.Detail.chipHorizontalPadding)
                    .padding(.vertical, Theme.Detail.chipVerticalPadding)
                    .background(
                        Theme.Detail.doneStateBackground,
                        in: RoundedRectangle(cornerRadius: Theme.Detail.chipRadius, style: .continuous)
                    )
            }
            if let due = Self.overdue(priority: priority, now: now) {
                DueChip(state: due, horizontalPadding: Theme.Detail.chipHorizontalPadding)
            }
            if !priority.isDone, let todayChip {
                DueChip(state: todayChip, horizontalPadding: Theme.Detail.chipHorizontalPadding)
            }
            Spacer(minLength: 0)
        }
    }
}
