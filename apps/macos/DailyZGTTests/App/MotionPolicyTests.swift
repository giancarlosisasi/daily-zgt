import Foundation
import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct MotionPolicyTests {
    private static let tokens: [(MotionStyle, Animation)] = [
        (.press, Theme.Motion.press),
        (.pop, Theme.Motion.panelPop),
        (.rowIn, Theme.Motion.out),
        (.rowOut, Theme.Motion.slowOut),
        (.fade, Theme.Motion.fade),
        (.slide, Theme.Motion.spring),
        (.caret, Theme.Motion.spring),
        (.draw, Theme.Motion.slowOut),
    ]

    @Test
    func theTableCoversEachStyle() {
        #expect(Self.tokens.count == MotionStyle.allCases.count)
        for style in MotionStyle.allCases {
            #expect(Self.tokens.contains { $0.0 == style }, "\(style)")
        }
    }

    @Test
    func withReduceMotionOffEachStyleGivesItsTeclaToken() {
        let policy = MotionPolicy(reduceMotion: false)

        #expect(policy.animates)
        for (style, token) in Self.tokens {
            #expect(policy.animation(style) == token, "\(style)")
        }
    }

    @Test
    func withReduceMotionOnNoStyleGivesAnAnimation() {
        let policy = MotionPolicy(reduceMotion: true)

        #expect(!policy.animates)
        for style in MotionStyle.allCases {
            #expect(policy.animation(style) == nil, "\(style)")
        }
    }

    @Test
    func theLeaveDelayIsTheSlowDurationOrZero() {
        #expect(MotionPolicy(reduceMotion: false).leaveDelay == Duration.tecla(TeclaTokens.Durations.slow))
        #expect(MotionPolicy(reduceMotion: false).leaveDelay > .zero)
        #expect(MotionPolicy(reduceMotion: true).leaveDelay == .zero)
    }

    @Test
    func theTokensComeFromTecla() {
        #expect(Theme.Motion.panelPop == Animation.timingCurve(0.2, 0.8, 0.2, 1.0, duration: 0.2))
        #expect(Theme.Motion.slowOut == Animation.timingCurve(0.2, 0.8, 0.2, 1.0, duration: 0.32))
        #expect(Theme.Motion.spring == Animation.spring(response: 0.22, dampingFraction: 1.0))
    }

    @Test
    func aRevealedPanelIsAtRestAndAHiddenOneIsSmallAndHigh() {
        let rest = PopFrame(revealed: true)
        let start = PopFrame(revealed: false)

        #expect(rest.opacity == 1)
        #expect(rest.scale == 1)
        #expect(rest.offsetY == 0)
        #expect(start.opacity == 0)
        #expect(start.scale == 0.96)
        #expect(start.offsetY == -8)
    }

    @Test
    func theRevealStartsHiddenAndEndsShown() {
        #expect(RevealPhase.allCases == [.rest, .start, .end])
        #expect(RevealPhase.rest.isRevealed)
        #expect(!RevealPhase.start.isRevealed)
        #expect(RevealPhase.end.isRevealed)
    }

    @Test
    func theBellRingStartsAndEndsAtRest() {
        let angles = Theme.MotionShape.ringAngles

        #expect(angles.first == 0)
        #expect(angles.last == 0)
        #expect(angles.count == 6)
    }

    @Test(arguments: [false, true])
    func theRowThatIsMarkedDoneLeavesAfterTheAnimationOrAtOnce(reduceMotion: Bool) throws {
        let recorder = ScheduleRecorder()
        let store = try makeStore(TestClock("2026-10-12T10:24:00"))
        let flow = PriorityFlow(store: store, schedule: recorder.schedule)
        let first = try store.addPriority(title: "First", list: .today)
        flow.toggleConfirmation(for: first.id)

        flow.confirmDone(first.id, leaving: MotionPolicy(reduceMotion: reduceMotion).leaveDelay)

        if reduceMotion {
            #expect(!flow.isLeaving(first.id))
            #expect(store.priority(id: first.id)?.isDone == true)
            #expect(flow.undo?.priorityID == first.id)
            #expect(recorder.entries.map(\.delay) == [Theme.Timing.undoLifetime])
        } else {
            #expect(flow.isLeaving(first.id))
            #expect(store.priority(id: first.id)?.isDone == false)
            #expect(recorder.entries.map(\.delay) == [.milliseconds(320)])
            recorder.fire(0)
            #expect(store.priority(id: first.id)?.isDone == true)
            #expect(flow.undo?.priorityID == first.id)
        }
    }

    @Test
    func theUndoBarGoesAwayAfterItsLifetimeWithEitherSetting() throws {
        for reduceMotion in [false, true] {
            let recorder = ScheduleRecorder()
            let store = try makeStore(TestClock("2026-10-12T10:24:00"))
            let flow = PriorityFlow(store: store, schedule: recorder.schedule)
            let first = try store.addPriority(title: "First", list: .today)
            flow.confirmDone(first.id, leaving: MotionPolicy(reduceMotion: reduceMotion).leaveDelay)
            if !reduceMotion {
                recorder.fire(0)
            }
            #expect(flow.undo != nil)
            #expect(recorder.entries.last?.delay == Theme.Timing.undoLifetime)

            recorder.fire(recorder.entries.count - 1)

            #expect(flow.undo == nil)
        }
    }

    @Test
    func theKeyPressAnimationFollowsThePolicy() {
        #expect(KeyPress(isPressed: true).animation == Theme.Motion.press)
        #expect(KeyPress(isPressed: true, reduceMotion: true).animation == nil)
        #expect(KeyPress(isPressed: true, reduceMotion: true).offset == 0)
        #expect(KeyPress(isPressed: true, reduceMotion: true).showsPressedTint)
    }
}
