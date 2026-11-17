import AppKit
import SwiftUI

enum MotionStyle: CaseIterable, Sendable {
    case press
    case pop
    case ring
    case slide

    var animation: Animation {
        switch self {
        case .press: Theme.Motion.press
        case .pop: Theme.Motion.panelPop
        case .ring: Theme.Motion.fade
        case .slide: Theme.Motion.spring
        }
    }
}

struct MotionPolicy: Equatable, Sendable {
    var reduceMotion: Bool

    var animates: Bool { !reduceMotion }

    var popDuration: Duration {
        reduceMotion ? .zero : Duration.tecla(Theme.Motion.panelOpen)
    }

    func animation(_ style: MotionStyle) -> Animation? {
        reduceMotion ? nil : style.animation
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
                policy.animation(.ring)
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

    func panelPop() -> some View {
        modifier(PanelPop())
    }

    func bellRing(trigger: Int) -> some View {
        modifier(BellRing(trigger: trigger))
    }
}
