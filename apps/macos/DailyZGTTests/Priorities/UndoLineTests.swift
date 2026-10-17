import Foundation
import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct UndoLineTests {
    let clock = TestClock("2026-10-12T10:24:00")
    let recorder = ScheduleRecorder()

    private func makeFlow(_ store: AppStore) -> PriorityFlow {
        PriorityFlow(store: store, schedule: recorder.schedule)
    }

    @Test
    func theLineIsFullWhenTheTimerStarts() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)
        let first = try store.addPriority(title: "First", list: .today)

        flow.confirmDone(first.id)
        let undo = try #require(flow.undo)

        #expect(undo.startedAt == clock.date)
        #expect(undo.lifetime == Theme.Timing.undoLifetime)
        #expect(recorder.entries.map(\.delay) == [undo.lifetime])
        #expect(undo.remainingFraction(at: store.now()) == 1)
    }

    @Test
    func theLineGetsShorterWhileTheTimerRuns() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)
        let first = try store.addPriority(title: "First", list: .today)
        flow.confirmDone(first.id)
        let undo = try #require(flow.undo)
        let total = TeclaTokens.Durations.undo

        clock.date.addTimeInterval(total / 2)
        #expect(abs(undo.remainingFraction(at: store.now()) - 0.5) < 0.0001)

        clock.date.addTimeInterval(total / 2)
        #expect(undo.remainingFraction(at: store.now()) == 0)

        clock.date.addTimeInterval(total)
        #expect(undo.remainingFraction(at: store.now()) == 0)
    }

    @Test
    func theLineGoesWithTheBarWhenTheTimerEnds() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)
        let first = try store.addPriority(title: "First", list: .today)
        flow.confirmDone(first.id)

        recorder.fire(0)

        #expect(flow.undo == nil)
    }

    @Test
    func aSecondDoneStartsANewFullLine() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)
        let first = try store.addPriority(title: "First", list: .today)
        let second = try store.addPriority(title: "Second", list: .today)
        flow.confirmDone(first.id)
        clock.date.addTimeInterval(3)

        flow.confirmDone(second.id)
        let undo = try #require(flow.undo)

        #expect(undo.title == "Second")
        #expect(undo.startedAt == clock.date)
        #expect(undo.remainingFraction(at: store.now()) == 1)
    }

    @Test
    func theLineDoesNotMoveWithReduceMotion() throws {
        let store = try makeStore(clock)
        let flow = makeFlow(store)
        let first = try store.addPriority(title: "First", list: .today)
        flow.confirmDone(first.id)
        let undo = try #require(flow.undo)

        clock.date.addTimeInterval(3)

        #expect(undo.lineFraction(at: store.now(), reduceMotion: true) == 1)
        #expect(undo.lineFraction(at: store.now(), reduceMotion: false) < 1)
    }

    @Test
    func rendersTheUndoLineAtThreeMoments() throws {
        let view = VStack(spacing: 8) {
            UndoBar(title: "Enviar la propuesta", remaining: 1, onUndo: {})
            UndoBar(title: "Enviar la propuesta", remaining: 0.5, onUndo: {})
            UndoBar(title: "Enviar la propuesta", remaining: 0.08, onUndo: {})
        }
        let url = try Screenshot.writeHosted(view.panelChrome(), named: "undo-line")
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }
}
