import SwiftUI

enum PriorityOrder {
    static func moving(_ id: Priority.ID, toGap gap: Int, in ids: [Priority.ID]) -> [Priority.ID] {
        guard let from = ids.firstIndex(of: id), (0...ids.count).contains(gap) else { return ids }
        var result = ids
        result.remove(at: from)
        result.insert(id, at: gap > from ? gap - 1 : gap)
        return result
    }

    static func changesOrder(_ id: Priority.ID, gap: Int, in ids: [Priority.ID]) -> Bool {
        moving(id, toGap: gap, in: ids) != ids
    }

    static func gap(at y: CGFloat, midpoints: [CGFloat]) -> Int {
        midpoints.firstIndex { y < $0 } ?? midpoints.count
    }
}

struct PriorityDrag: Equatable {
    let id: Priority.ID
    var gap: Int?
}

@MainActor
final class RowFrames {
    private var values: [Priority.ID: CGRect] = [:]

    func set(_ frame: CGRect, for id: Priority.ID) {
        values[id] = frame
    }

    func midpoints(of ids: [Priority.ID]) -> [CGFloat] {
        ids.map { values[$0]?.midY ?? .greatestFiniteMagnitude }
    }
}

struct PriorityStackDropDelegate: DropDelegate {
    let ids: [Priority.ID]
    let frames: RowFrames
    let list: PriorityList
    let flow: PriorityFlow

    func validateDrop(info: DropInfo) -> Bool {
        flow.drag != nil
    }

    func dropEntered(info: DropInfo) {
        hover(info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        hover(info)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        flow.hover(gap: nil, in: list)
    }

    func performDrop(info: DropInfo) -> Bool {
        hover(info)
        flow.drop(in: list)
        return true
    }

    private func hover(_ info: DropInfo) {
        flow.hover(gap: PriorityOrder.gap(at: info.location.y, midpoints: frames.midpoints(of: ids)), in: list)
    }
}

struct DropLine: View {
    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .strokeBorder(Theme.Row.dropLine, lineWidth: Theme.Row.dropLineHeight)
                .frame(width: Theme.Row.dropDotSize, height: Theme.Row.dropDotSize)
            Rectangle()
                .fill(Theme.Row.dropLine)
                .frame(height: Theme.Row.dropLineHeight)
        }
        .frame(height: Theme.Row.dropDotSize)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    func dropLine(at edge: VerticalEdge, isVisible: Bool, isListEdge: Bool) -> some View {
        let offset = isListEdge ? 0 : Theme.Row.dropLineOffset
        return overlay(alignment: edge == .top ? .top : .bottom) {
            if isVisible {
                DropLine()
                    .offset(y: edge == .top ? -offset : offset)
            }
        }
    }
}
