import SwiftUI

enum SwitchGeometry {
    static func knobOffset(isOn: Bool) -> CGFloat {
        isOn ? Theme.Switch.travel : 0
    }

    static func trackColor(isOn: Bool) -> Color {
        isOn ? Theme.Switch.onTrack : Theme.Switch.offTrack
    }
}

struct SettingsToggle: View {
    let title: String
    let isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Button(action: { onChange(!isOn) }) {
            Color.clear
        }
        .buttonStyle(SwitchButtonStyle(isOn: isOn))
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "Activado" : "Desactivado")
        .accessibilityAddTraits(.isToggle)
    }
}

struct SwitchButtonStyle: ButtonStyle {
    let isOn: Bool

    func makeBody(configuration: Configuration) -> some View {
        SwitchFace(isOn: isOn, isPressed: configuration.isPressed)
    }
}

struct SwitchFace: View {
    let isOn: Bool
    var isPressed = false

    @Environment(\.motionPolicy) private var motion

    var body: some View {
        ZStack(alignment: .leading) {
            track
            KeyFace(
                face: Theme.Switch.knob,
                side: Theme.Key.side,
                radius: Theme.Switch.knobRadius,
                press: KeyPress(isPressed: isPressed, reduceMotion: motion.reduceMotion)
            ) {
                Color.clear
                    .frame(width: Theme.Switch.knobSize, height: Theme.Switch.knobSize)
            }
            .padding(.leading, Theme.Switch.inset)
            .offset(x: SwitchGeometry.knobOffset(isOn: isOn))
        }
        .frame(width: Theme.Switch.width, height: Theme.Switch.height)
        .contentShape(Capsule())
        .motion(.slide, value: isOn)
    }

    private var track: some View {
        Capsule()
            .fill(SwitchGeometry.trackColor(isOn: isOn))
            .overlay {
                Capsule()
                    .fill(Theme.Switch.well)
                    .mask {
                        Capsule()
                            .overlay {
                                Capsule()
                                    .offset(y: Theme.Switch.wellHeight)
                                    .blendMode(.destinationOut)
                            }
                            .compositingGroup()
                    }
            }
    }
}
