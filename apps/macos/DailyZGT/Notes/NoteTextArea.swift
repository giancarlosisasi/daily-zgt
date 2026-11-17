import SwiftUI

struct NoteTextArea: View {
    @Binding var text: String
    let placeholder: String
    var minHeight = Theme.Notes.panelMinHeight
    var maxHeight: CGFloat?

    @FocusState private var isFocused: Bool
    @Environment(\.panelLayout) private var layout

    private var font: Font {
        layout == .window ? Theme.Notes.windowFont : Theme.Font.body
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Notes.radius, style: .continuous)
        ZStack(alignment: .topLeading) {
            Text(text + "\n ")
                .font(font)
                .lineSpacing(Theme.Notes.lineSpacing)
                .padding(Theme.Notes.padding)
                .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
                .hidden()
                .accessibilityHidden(true)
            TextEditor(text: $text)
                .font(font)
                .lineSpacing(Theme.Notes.lineSpacing)
                .foregroundStyle(Theme.Text.primary)
                .tint(Theme.Accent.caret)
                .scrollContentBackground(.hidden)
                .scrollDisabled(maxHeight == nil)
                .focused($isFocused)
                .padding(.horizontal, Theme.Notes.padding - Theme.Notes.editorInset)
                .padding(.vertical, Theme.Notes.padding)
            if text.isEmpty {
                Text(placeholder)
                    .font(font)
                    .foregroundStyle(Theme.Notes.placeholder)
                    .padding(Theme.Notes.padding)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxHeight: maxHeight)
        .clipShape(shape)
        .background(Theme.Notes.background, in: shape)
        .overlay {
            if isFocused {
                shape.strokeBorder(Theme.Accent.focusRing, lineWidth: Theme.Accent.focusRingWidth)
            }
        }
    }
}
