import SwiftUI

struct NoteTextArea: View {
    @Binding var text: String
    let placeholder: String
    var height = Theme.Notes.height
    var horizontalPadding = Theme.Notes.padding
    var verticalPadding = Theme.Notes.padding

    @FocusState private var isFocused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Notes.radius, style: .continuous)
        TextEditor(text: $text)
            .font(Theme.Font.body)
            .lineSpacing(Theme.Notes.lineSpacing)
            .foregroundStyle(Theme.Text.primary)
            .tint(Theme.Accent.caret)
            .scrollContentBackground(.hidden)
            .focused($isFocused)
            .padding(.horizontal, horizontalPadding + Theme.Notes.borderWidth - Theme.Notes.editorInset)
            .padding(.vertical, verticalPadding + Theme.Notes.borderWidth)
            .frame(height: height)
            .background(Theme.Notes.background, in: shape)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Notes.placeholder)
                        .padding(.horizontal, horizontalPadding + Theme.Notes.borderWidth)
                        .padding(.vertical, verticalPadding + Theme.Notes.borderWidth)
                        .allowsHitTesting(false)
                }
            }
            .overlay(shape.strokeBorder(Theme.Notes.border, lineWidth: 1))
            .overlay {
                if isFocused {
                    shape.strokeBorder(Theme.Accent.focusRing, lineWidth: Theme.Accent.focusRingWidth)
                }
            }
    }
}
