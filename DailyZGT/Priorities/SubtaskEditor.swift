import SwiftUI

enum SubtaskEditorStyle {
    case row
    case detail

    var spacing: CGFloat {
        switch self {
        case .row: Theme.SubtaskList.rowListSpacing
        case .detail: Theme.SubtaskList.detailSpacing
        }
    }

    var inputTop: CGFloat {
        switch self {
        case .row: Theme.SubtaskList.rowListInputTop
        case .detail: 0
        }
    }
}

struct SubtaskRowView: View {
    let subtask: Subtask
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: Theme.SubtaskList.rowSpacing) {
            PriorityCheckbox(
                isChecked: subtask.isDone,
                size: Theme.SubtaskList.checkboxSize,
                label: "Marcar subtarea",
                action: onToggle
            )
            Text(subtask.title)
                .font(Theme.SubtaskList.font)
                .foregroundStyle(subtask.isDone ? Theme.SubtaskList.doneText : Theme.SubtaskList.openText)
                .strikethrough(subtask.isDone)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .motion(.fade, value: subtask.isDone)
        }
        .frame(minHeight: Theme.SubtaskList.rowMinHeight)
    }
}

struct SubtaskEditor: View {
    let priorityID: Priority.ID
    let style: SubtaskEditorStyle

    @Environment(AppStore.self) private var store
    @State private var draft = ""
    @State private var writeFailed = false
    @FocusState private var isFocused: Bool

    private var actions: SubtaskActions { SubtaskActions(store: store, priorityID: priorityID) }

    var body: some View {
        VStack(alignment: .leading, spacing: style.spacing) {
            ForEach(store.subtasks(of: priorityID)) { subtask in
                SubtaskRowView(subtask: subtask) { toggle(subtask) }
            }
            input
                .padding(.top, style.inputTop)
            if writeFailed {
                Text("No se pudo guardar el cambio.")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Text.muted)
            }
        }
        .padding(.leading, style == .row ? Theme.SubtaskList.rowListLeading : 0)
        .padding(.trailing, style == .row ? Theme.SubtaskList.rowListTrailing : 0)
        .padding(.bottom, style == .row ? Theme.SubtaskList.rowListBottom : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var input: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.SubtaskList.inputRadius, style: .continuous)
        return TextField("", text: $draft)
            .textFieldStyle(.plain)
            .font(Theme.SubtaskList.font)
            .foregroundStyle(Theme.Text.primary)
            .tint(Theme.Accent.caret)
            .focused($isFocused)
            .onSubmit(submit)
            .overlay(alignment: .leading) {
                if draft.isEmpty {
                    Text("Añadir subtarea y Enter")
                        .font(Theme.SubtaskList.font)
                        .foregroundStyle(Theme.Text.dim)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, Theme.SubtaskList.inputPadding)
            .frame(height: Theme.SubtaskList.inputHeight)
            .background(Theme.SubtaskList.inputBackground, in: shape)
            .overlay(shape.strokeBorder(Theme.SubtaskList.inputBorder, lineWidth: 1))
            .overlay {
                if isFocused {
                    shape.strokeBorder(Theme.Accent.focusRing, lineWidth: Theme.Accent.focusRingWidth)
                }
            }
            .accessibilityLabel("Nueva subtarea")
    }

    private func submit() {
        defer { isFocused = true }
        do {
            if try actions.add(draft) != nil {
                draft = ""
            }
            writeFailed = false
        } catch {
            writeFailed = true
        }
    }

    private func toggle(_ subtask: Subtask) {
        do {
            try actions.toggle(subtask.id)
            writeFailed = false
        } catch {
            writeFailed = true
        }
    }
}
