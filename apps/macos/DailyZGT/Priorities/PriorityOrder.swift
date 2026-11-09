import SwiftUI
import UniformTypeIdentifiers

enum PriorityOrder {
    static func moving(_ id: Priority.ID, to target: Priority.ID, in ids: [Priority.ID]) -> [Priority.ID] {
        guard id != target, let from = ids.firstIndex(of: id), let to = ids.firstIndex(of: target) else {
            return ids
        }
        var result = ids
        result.remove(at: from)
        result.insert(id, at: to)
        return result
    }
}

struct PriorityDropDelegate: DropDelegate {
    let target: Priority.ID
    let list: PriorityList
    let flow: PriorityFlow

    func validateDrop(info: DropInfo) -> Bool {
        flow.draggingID != nil
    }

    func dropEntered(info: DropInfo) {
        flow.dragEntered(target, in: list)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        flow.endDrag()
        return true
    }
}

extension View {
    func reorderable(_ priority: Priority, in list: PriorityList, flow: PriorityFlow) -> some View {
        onDrag {
            flow.startDrag(priority.id)
            return NSItemProvider(object: priority.id as NSString)
        }
        .onDrop(of: [UTType.text], delegate: PriorityDropDelegate(target: priority.id, list: list, flow: flow))
    }
}
