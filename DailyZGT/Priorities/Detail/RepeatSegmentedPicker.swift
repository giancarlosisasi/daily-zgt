import SwiftUI

struct RepeatSegmentedPicker: View {
    @Binding var selection: RepeatRule

    var body: some View {
        HStack(spacing: Theme.Segmented.trackSpacing) {
            ForEach(RepeatRule.allCases, id: \.self) { rule in
                RepeatSegmentButton(rule: rule, isSelected: selection == rule) {
                    selection = rule
                }
            }
        }
        .padding(Theme.Segmented.trackPadding)
        .background(
            Theme.NewPriority.inputBackground,
            in: RoundedRectangle(cornerRadius: Theme.NewPriority.segmentTrackRadius, style: .continuous)
        )
        .motion(.fade, value: selection)
    }
}

private struct RepeatSegmentButton: View {
    let rule: RepeatRule
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            SegmentFace(isSelected: isSelected, radius: Theme.NewPriority.segmentRadius) {
                Text(rule.title)
                    .font(Theme.Font.label)
                    .foregroundStyle(foreground)
                    .frame(maxWidth: .infinity)
                    .frame(height: Theme.NewPriority.segmentHeight)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var foreground: Color {
        if isSelected { return Theme.Segmented.selectedText }
        return isHovering ? Theme.Segmented.hoverText : Theme.Segmented.unselectedText
    }
}
