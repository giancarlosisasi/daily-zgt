import AppKit
import SwiftUI

enum MotionStyle: CaseIterable, Sendable {
    case press
    case pop
    case rowIn
    case rowOut
    case fade
    case slide
    case caret
    case draw

    var animation: Animation {
        switch self {
        case .press: Theme.Motion.press
        case .pop: Theme.Motion.panelPop
        case .rowIn: Theme.Motion.out
        case .rowOut: Theme.Motion.slowOut
        case .fade: Theme.Motion.fade
        case .slide: Theme.Motion.spring
        case .caret: Theme.Motion.spring
        case .draw: Theme.Motion.slowOut
        }
    }
}

enum MotionTransition: CaseIterable, Sendable {
    case rowIn
    case fadeIn
    case slideIn
    case slideBack

    var insertion: AnyTransition {
        switch self {
        case .rowIn: .opacity.combined(with: .offset(y: -Theme.MotionShape.rowInOffset))
        case .fadeIn: .opacity
        case .slideIn: .opacity.combined(with: .offset(x: Theme.MotionShape.slideOffset))
        case .slideBack: .opacity.combined(with: .offset(x: -Theme.MotionShape.slideOffset))
        }
    }
}

struct MotionPolicy: Equatable, Sendable {
    var reduceMotion: Bool

    var animates: Bool { !reduceMotion }

    var leaveDelay: Duration {
        reduceMotion ? .zero : Duration.tecla(Theme.Motion.slow)
    }

    var popDuration: Duration {
        reduceMotion ? .zero : Duration.tecla(Theme.Motion.panelOpen)
    }

    func animation(_ style: MotionStyle) -> Animation? {
        reduceMotion ? nil : style.animation
    }

    func transition(_ kind: MotionTransition) -> AnyTransition {
        reduceMotion ? .identity : .asymmetric(insertion: kind.insertion, removal: .identity)
    }

    func perform(_ style: MotionStyle, _ body: () -> Void) {
        withAnimation(animation(style), body)
    }
}

extension EnvironmentValues {
    var motionPolicy: MotionPolicy {
        MotionPolicy(reduceMotion: accessibilityReduceMotion)
    }
}

struct PopFrame: Equatable {
    let revealed: Bool

    var opacity: Double { revealed ? 1 : 0 }
    var scale: CGFloat { revealed ? 1 : Theme.MotionShape.popScale }
    var offsetY: CGFloat { revealed ? 0 : -Theme.MotionShape.popOffset }
}

enum RevealPhase: CaseIterable, Sendable {
    case rest
    case start
    case end

    var isRevealed: Bool { self != .start }
}

private struct MotionValue<Value: Equatable>: ViewModifier {
    let style: MotionStyle
    let value: Value

    @Environment(\.motionPolicy) private var policy

    func body(content: Content) -> some View {
        content.animation(policy.animation(style), value: value)
    }
}

private struct MotionTransitionModifier: ViewModifier {
    let kind: MotionTransition

    @Environment(\.motionPolicy) private var policy

    func body(content: Content) -> some View {
        content.transition(policy.transition(kind))
    }
}

private struct FadeInOnChange<Value: Equatable>: ViewModifier {
    let value: Value

    @Environment(\.motionPolicy) private var policy

    func body(content: Content) -> some View {
        if policy.animates {
            content.phaseAnimator(RevealPhase.allCases, trigger: value) { view, phase in
                view.opacity(phase.isRevealed ? 1 : 0)
            } animation: { phase in
                phase == .end ? policy.animation(.fade) : nil
            }
        } else {
            content
        }
    }
}

private struct PanelPop: ViewModifier {
    @Environment(\.motionPolicy) private var policy
    @State private var playCount = 0

    func body(content: Content) -> some View {
        Group {
            if policy.animates {
                content.phaseAnimator(RevealPhase.allCases, trigger: playCount) { view, phase in
                    let frame = PopFrame(revealed: phase.isRevealed)
                    view
                        .opacity(frame.opacity)
                        .scaleEffect(frame.scale, anchor: .topTrailing)
                        .offset(y: frame.offsetY)
                } animation: { phase in
                    phase == .end ? policy.animation(.pop) : nil
                }
            } else {
                content
            }
        }
        .onAppear { playCount += 1 }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didChangeOcclusionStateNotification)) { note in
            if let window = note.object as? NSWindow,
               window.className.contains("MenuBarExtraWindow"),
               window.occlusionState.contains(.visible) {
                playCount += 1
            }
        }
    }
}

private struct BellRing: ViewModifier {
    let trigger: Int

    @Environment(\.motionPolicy) private var policy

    func body(content: Content) -> some View {
        if policy.animates {
            content.phaseAnimator(Theme.MotionShape.ringAngles, trigger: trigger) { view, angle in
                view.rotationEffect(.degrees(angle), anchor: Theme.MotionShape.ringAnchor)
            } animation: { _ in
                policy.animation(.fade)
            }
        } else {
            content
        }
    }
}

extension View {
    func motion(_ style: MotionStyle, value: some Equatable) -> some View {
        modifier(MotionValue(style: style, value: value))
    }

    func motion(_ policy: MotionPolicy, _ style: MotionStyle, value: some Equatable) -> some View {
        animation(policy.animation(style), value: value)
    }

    func motionTransition(_ kind: MotionTransition) -> some View {
        modifier(MotionTransitionModifier(kind: kind))
    }

    func fadeIn(on value: some Equatable) -> some View {
        modifier(FadeInOnChange(value: value))
    }

    func panelPop() -> some View {
        modifier(PanelPop())
    }

    func bellRing(trigger: Int) -> some View {
        modifier(BellRing(trigger: trigger))
    }
}
