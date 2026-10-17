import SwiftUI

struct CheckboxKeyStyle: ButtonStyle {
    let isChecked: Bool
    let size: CGFloat
    var showsPressed = false

    func makeBody(configuration: Configuration) -> some View {
        CheckboxKeyBody(configuration: configuration, isChecked: isChecked, size: size, showsPressed: showsPressed)
    }
}

private struct CheckboxKeyBody: View {
    let configuration: ButtonStyleConfiguration
    let isChecked: Bool
    let size: CGFloat
    let showsPressed: Bool

    @Environment(\.motionPolicy) private var motion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Checkbox.radius, style: .continuous)
        KeyFace(
            face: isChecked ? Theme.Checkbox.checkedFill : Theme.Checkbox.fill,
            side: Theme.Key.side,
            radius: Theme.Checkbox.radius,
            press: KeyPress(
                isPressed: configuration.isPressed || showsPressed,
                staysDown: isChecked,
                reduceMotion: motion.reduceMotion
            )
        ) {
            ZStack {
                if isChecked {
                    IconView(icon: .check, size: size * Theme.Checkbox.checkRatio)
                        .foregroundStyle(Theme.Checkbox.check)
                } else {
                    shape.strokeBorder(Theme.Checkbox.border, lineWidth: Theme.Checkbox.borderWidth)
                }
            }
            .frame(width: size, height: size)
        }
        .contentShape(Rectangle())
    }
}

struct PriorityCheckbox: View {
    let isChecked: Bool
    var size: CGFloat = Theme.Row.checkboxSize
    var label = "Marcar como hecha"
    var showsPressed = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            EmptyView()
        }
        .buttonStyle(CheckboxKeyStyle(isChecked: isChecked, size: size, showsPressed: showsPressed))
        .accessibilityLabel(label)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }
}
