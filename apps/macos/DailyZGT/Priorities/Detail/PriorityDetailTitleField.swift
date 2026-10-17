import SwiftUI

struct PriorityDetailTitleField: View {
    let title: String
    let onCommit: (String) -> String
    let showsEditState: Bool

    @State private var draft: String
    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    init(title: String, showsEditState: Bool = false, onCommit: @escaping (String) -> String) {
        self.title = title
        self.showsEditState = showsEditState
        self.onCommit = onCommit
        _draft = State(initialValue: title)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Detail.titleRadius, style: .continuous)
        TextField("", text: $draft)
            .textFieldStyle(.plain)
            .font(Theme.Detail.titleFont)
            .foregroundStyle(Theme.Text.strong)
            .tint(Theme.Accent.caret)
            .focused($isFocused)
            .padding(.horizontal, Theme.Detail.titleInset)
            .frame(height: Theme.Detail.titleHeight)
            .overlay(shape.strokeBorder(isHovering ? Theme.Detail.titleHoverBorder : Color.clear, lineWidth: 1))
            .overlay {
                if isFocused || showsEditState {
                    shape.strokeBorder(Theme.Accent.focusRing, lineWidth: Theme.Accent.focusRingWidth)
                }
            }
            .padding(.horizontal, -Theme.Detail.titleInset)
            .onHover { isHovering = $0 }
            .onSubmit {
                draft = onCommit(draft)
                isFocused = false
            }
            .onExitCommand {
                draft = title
                isFocused = false
            }
            .onChange(of: isFocused) { _, focused in
                if !focused {
                    draft = onCommit(draft)
                }
            }
            .onChange(of: title) { _, newTitle in
                if !isFocused {
                    draft = newTitle
                }
            }
            .onAppear { isFocused = showsEditState }
            .accessibilityLabel("Título")
    }
}
