import SwiftUI

enum KeyRole: Equatable {
    case primary
    case graphite

    var face: Color {
        switch self {
        case .primary: Theme.Key.accentFace
        case .graphite: Theme.Key.face
        }
    }

    var side: Color {
        switch self {
        case .primary: Theme.Key.accentSide
        case .graphite: Theme.Key.side
        }
    }

    var text: Color {
        switch self {
        case .primary: Theme.Key.accentText
        case .graphite: Theme.Key.text
        }
    }
}

struct KeyPress: Equatable {
    var isPressed = false
    var staysDown = false
    var reduceMotion = false

    static let up = KeyPress()

    var isDown: Bool {
        staysDown || (isPressed && !reduceMotion)
    }

    var offset: CGFloat {
        isDown ? Theme.Key.travel : 0
    }

    var sideHeight: CGFloat {
        Theme.Key.sideHeight - offset
    }

    var showsPressedTint: Bool {
        isPressed && reduceMotion
    }

    var animation: Animation? {
        MotionPolicy(reduceMotion: reduceMotion).animation(.press)
    }
}

struct KeyFace<Label: View>: View {
    let face: Color
    let side: Color
    let radius: CGFloat
    var press = KeyPress.up
    @ViewBuilder let label: Label

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        label
            .background(face, in: shape)
            .overlay {
                if press.showsPressedTint {
                    shape.fill(Theme.Key.pressedTint)
                }
            }
            .offset(y: press.offset)
            .background {
                shape
                    .fill(side)
                    .offset(y: Theme.Key.sideHeight)
                    .opacity(press.sideHeight > 0 ? 1 : 0)
            }
            .motion(MotionPolicy(reduceMotion: press.reduceMotion), .press, value: press.offset)
    }
}

struct KeyButtonStyle: ButtonStyle {
    var role = KeyRole.graphite
    var radius = Theme.Key.radius
    var showsPressed = false

    func makeBody(configuration: Configuration) -> some View {
        KeyButtonBody(configuration: configuration, role: role, radius: radius, showsPressed: showsPressed)
    }
}

private struct KeyButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let role: KeyRole
    let radius: CGFloat
    let showsPressed: Bool

    @Environment(\.motionPolicy) private var motion

    var body: some View {
        KeyFace(
            face: role.face,
            side: role.side,
            radius: radius,
            press: KeyPress(isPressed: configuration.isPressed || showsPressed, reduceMotion: motion.reduceMotion)
        ) {
            configuration.label
                .foregroundStyle(role.text)
        }
        .contentShape(Rectangle())
    }
}

struct GhostButtonStyle: ButtonStyle {
    var radius = Theme.Ghost.radius

    func makeBody(configuration: Configuration) -> some View {
        GhostButtonBody(configuration: configuration, radius: radius)
    }
}

private struct GhostButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let radius: CGFloat

    @State private var isHovering = false

    var body: some View {
        configuration.label
            .background(
                isHovering || configuration.isPressed ? Theme.Ghost.hoverBackground : Color.clear,
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
    }
}

extension ButtonStyle where Self == KeyButtonStyle {
    static var primaryKey: KeyButtonStyle { KeyButtonStyle(role: .primary) }
    static var graphiteKey: KeyButtonStyle { KeyButtonStyle(role: .graphite) }
}

extension ButtonStyle where Self == GhostButtonStyle {
    static var ghost: GhostButtonStyle { GhostButtonStyle() }
}
