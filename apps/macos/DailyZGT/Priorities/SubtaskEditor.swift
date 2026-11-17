import SwiftUI

enum SubtaskEditorStyle {
    case row
    case detail
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
        }
        .frame(minHeight: Theme.SubtaskList.rowMinHeight)
    }
}

struct SubtaskEditor: View {
    static let addTitle = "Añadir subtarea"

    let priorityID: Priority.ID
    let style: SubtaskEditorStyle
    var startsAdding = false

    @Environment(AppStore.self) private var store
    @State private var draft = ""
    @State private var writeFailed = false
    @State private var isAdding = false
    @FocusState private var isFocused: Bool

    private var actions: SubtaskActions { SubtaskActions(store: store, priorityID: priorityID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(store.subtasks(of: priorityID)) { subtask in
                SubtaskRowView(subtask: subtask) { toggle(subtask) }
            }
            if isAdding || startsAdding {
                input
            } else {
                addButton
            }
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

    private var addButton: some View {
        Button {
            isAdding = true
            isFocused = true
        } label: {
            HStack(spacing: Theme.SubtaskList.rowSpacing) {
                IconView(icon: .plus, size: Theme.SubtaskList.addIconSize)
                    .frame(width: Theme.SubtaskList.checkboxSize)
                Text(Self.addTitle)
                    .font(Theme.SubtaskList.font)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.SubtaskList.addText)
            .frame(minHeight: Theme.SubtaskList.rowMinHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.addTitle)
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
            .onExitCommand(perform: close)
            .overlay(alignment: .leading) {
                if draft.isEmpty {
                    Text("\(Self.addTitle) y Enter")
                        .font(Theme.SubtaskList.font)
                        .foregroundStyle(Theme.Text.dim)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, Theme.SubtaskList.inputPadding)
            .frame(height: Theme.SubtaskList.inputHeight)
            .background(Theme.SubtaskList.inputBackground, in: shape)
            .overlay {
                if isFocused {
                    shape.strokeBorder(Theme.Accent.focusRing, lineWidth: Theme.Accent.focusRingWidth)
                }
            }
            .onAppear { isFocused = true }
            .onChange(of: isFocused) { _, focused in
                if !focused, draft.isEmpty {
                    isAdding = false
                }
            }
            .accessibilityLabel("Nueva subtarea")
    }

    private func close() {
        draft = ""
        isAdding = false
        isFocused = false
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
