import SwiftUI

struct PriorityDetailSubtasksSection: View {
    let priority: Priority

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Detail.sectionSpacing) {
            DetailSectionTitle(text: "SUBTAREAS")
            SubtaskEditor(priorityID: priority.id, style: .detail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
