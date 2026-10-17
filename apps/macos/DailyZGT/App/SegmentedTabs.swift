import SwiftUI

enum SegmentedStyle {
    case top
    case scope
}

struct SegmentFace<Label: View>: View {
    let isSelected: Bool
    let radius: CGFloat
    @ViewBuilder let label: Label

    var body: some View {
        if isSelected {
            KeyFace(face: Theme.Segmented.selectedBackground, side: Theme.Key.side, radius: radius) {
                label
            }
        } else {
            label
        }
    }
}

struct SegmentedTabs<Value: Hashable>: View {
    struct Option: Identifiable {
        let value: Value
        let title: String
        var id: Value { value }
    }

    let style: SegmentedStyle
    let options: [Option]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: Theme.Segmented.trackSpacing) {
            ForEach(options) { option in
                SegmentButton(
                    style: style,
                    title: option.title,
                    isSelected: option.value == selection
                ) {
                    selection = option.value
                }
            }
        }
        .padding(Theme.Segmented.trackPadding)
        .background(track, in: RoundedRectangle(cornerRadius: trackRadius, style: .continuous))
        .motion(.fade, value: selection)
    }

    private var track: Color {
        switch style {
        case .top: Theme.Segmented.Top.track
        case .scope: Theme.Segmented.Scope.track
        }
    }

    private var trackRadius: CGFloat {
        switch style {
        case .top: Theme.Segmented.Top.trackRadius
        case .scope: Theme.Segmented.Scope.trackRadius
        }
    }
}

private struct SegmentButton: View {
    let style: SegmentedStyle
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            SegmentFace(isSelected: isSelected, radius: radius) {
                label
                    .foregroundStyle(foreground)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .motion(.fade, value: isHovering)
        .onHover { isHovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var label: some View {
        switch style {
        case .top:
            Text(title)
                .font(Theme.Font.topTab)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.Segmented.Top.buttonHeight)
        case .scope:
            Text(title)
                .font(Theme.Font.scopeTab)
                .padding(.horizontal, Theme.Segmented.Scope.buttonPadding)
                .frame(height: Theme.Segmented.Scope.buttonHeight)
        }
    }

    private var radius: CGFloat {
        switch style {
        case .top: Theme.Segmented.Top.buttonRadius
        case .scope: Theme.Segmented.Scope.buttonRadius
        }
    }

    private var foreground: Color {
        if isSelected { return Theme.Segmented.selectedText }
        return isHovering ? Theme.Segmented.hoverText : Theme.Segmented.unselectedText
    }
}
