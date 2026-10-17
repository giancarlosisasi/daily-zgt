struct SubtaskExpansion: Equatable {
    private(set) var expandedIDs: Set<Priority.ID> = []

    func isExpanded(_ id: Priority.ID) -> Bool {
        expandedIDs.contains(id)
    }

    mutating func toggle(_ id: Priority.ID) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }
}
