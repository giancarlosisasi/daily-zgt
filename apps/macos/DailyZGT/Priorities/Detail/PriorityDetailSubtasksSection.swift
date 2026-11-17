import SwiftUI

struct PriorityDetailSubtasksSection: View {
    let priority: Priority
    var progress = SubtaskProgress(done: 0, total: 0)

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Detail.sectionSpacing) {
            DetailSectionTitle(text: "Subtareas", count: progress.total > 0 ? "\(progress.done)/\(progress.total)" : nil)
            SubtaskEditor(priorityID: priority.id, style: .detail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
