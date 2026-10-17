import Foundation
import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct MotionRenderTests {
    private func expectPNG(_ view: some View, named name: String) throws {
        let url = try Screenshot.writeHosted(view, named: name)
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func rendersTheCheckDrawFromStartToEnd() throws {
        let view = HStack(spacing: 16) {
            AllDoneMark(progress: 0)
            AllDoneMark(progress: 0.5)
            AllDoneMark(progress: 1)
        }
        try expectPNG(view.padding(16).background(Theme.Panel.background), named: "motion-draw")
    }

    @Test
    func rendersThePanelPopFromStartToEnd() throws {
        let store = try makeStore(TestClock("2026-10-12T10:24:00"))
        try store.addPriority(title: "Revisar el MR pendiente", level: .high, list: .today)
        try store.addPriority(title: "Ordenar el escritorio", level: .low, list: .today)
        func frame(_ revealed: Bool) -> some View {
            let pop = PopFrame(revealed: revealed)
            return PanelView()
                .environment(store)
                .environment(PanelState(store: store))
                .opacity(pop.opacity)
                .scaleEffect(pop.scale, anchor: .topTrailing)
                .offset(y: pop.offsetY)
                .padding(20)
        }
        try expectPNG(frame(false), named: "motion-pop-start")
        try expectPNG(frame(true), named: "motion-pop-end")
    }

    @Test
    func rendersTheRowBeforeAndWhileItLeaves() throws {
        let store = try makeStore(TestClock("2026-10-12T10:24:00"))
        let first = try store.addPriority(title: "Revisar el MR pendiente", level: .high, list: .today)
        try store.addPriority(title: "Ordenar el escritorio", level: .low, list: .today)
        let state = PanelState(store: store, priorityFlow: PriorityFlow(store: store, schedule: { _, _ in }))
        state.priorityFlow.toggleConfirmation(for: first.id)
        let view = PanelView().environment(store).environment(state)
        try expectPNG(view, named: "motion-row-confirming")

        state.priorityFlow.confirmDone(first.id, leaving: .milliseconds(320))
        try expectPNG(view, named: "motion-row-leaving")
        #expect(state.priorityFlow.isLeaving(first.id))
    }

    @Test
    func rendersTheCaretClosedAndOpen() throws {
        let store = try makeStore(TestClock("2026-10-12T10:24:00"))
        let first = try store.addPriority(title: "Revisar el MR pendiente", level: .high, list: .today)
        try store.addSubtask(to: first.id, title: "Listar las apps")
        let state = PanelState(store: store)
        let view = PanelView().environment(store).environment(state)
        try expectPNG(view, named: "motion-caret-closed")
        state.priorityFlow.toggleSubtasks(for: first.id)
        try expectPNG(view, named: "motion-caret-open")
    }
}
