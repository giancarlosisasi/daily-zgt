import SwiftUI

struct PriorityDetailTitleField: View {
    let title: String
    let onCommit: (String) -> String
    let showsEditState: Bool

    @State private var draft: String
    @State private var isHovering = false
    @FocusState private var isFocused: Bool
    @Environment(\.panelLayout) private var layout

    init(title: String, showsEditState: Bool = false, onCommit: @escaping (String) -> String) {
        self.title = title
        self.showsEditState = showsEditState
        self.onCommit = onCommit
        _draft = State(initialValue: title)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Detail.titleRadius, style: .continuous)
        TextField("", text: $draft, axis: .vertical)
            .textFieldStyle(.plain)
            .font(layout == .window ? Theme.Detail.windowTitleFont : Theme.Detail.titleFont)
            .foregroundStyle(Theme.Text.strong)
            .tint(Theme.Accent.caret)
            .lineLimit(1...6)
            .focused($isFocused)
            .padding(.horizontal, Theme.Detail.titleInset)
            .padding(.vertical, Theme.Detail.titleVerticalInset)
            .background(isHovering || isFocused ? Theme.Detail.titleHoverBackground : Color.clear, in: shape)
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
