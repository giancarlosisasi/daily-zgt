import SwiftUI
import UniformTypeIdentifiers

struct EmptyListContent: View {
    let filter: DueFilter
    let now: Date

    @Environment(AppStore.self) private var store

    var body: some View {
        let days = DueDays(now: now)
        if filter.resolved(days) == .today, !store.donePriorities(in: .today, days: days).isEmpty {
            VStack(spacing: Theme.AllDone.spacing) {
                AllDoneCheck()
                Text(DueFilterLabels.allDone)
                    .font(Theme.Font.bodyStrong)
                    .foregroundStyle(Theme.Text.primary)
            }
            .padding(.top, Theme.AllDone.topPadding)
            .padding(.bottom, Theme.AllDone.bottomPadding)
            .padding(.horizontal, Theme.AllDone.horizontalPadding)
            .frame(maxWidth: .infinity)
        } else {
            Text(DueFilterLabels.empty(filter, days))
                .font(Theme.Filter.emptyFont)
                .foregroundStyle(Theme.Filter.emptyText)
                .padding(.top, Theme.Filter.emptyTopPadding)
                .padding(.bottom, Theme.Filter.emptyBottomPadding)
                .padding(.horizontal, Theme.Filter.emptyHorizontalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct PriorityListView: View {
    let filter: DueFilter

    @Environment(AppStore.self) private var store
    @Environment(PanelState.self) private var panel
    @Environment(AlertCoordinator.self) private var alerts: AlertCoordinator?
    @State private var writeFailed = false
    @Environment(\.panelLayout) private var layout
    @State private var form = NewPriorityForm()
    @State private var frames = RowFrames()

    private static let stackSpace = "priorityStack"

    private var flow: PriorityFlow { panel.priorityFlow }

    var body: some View {
        VStack(spacing: 0) {
            openArea
            newPriority
            DoneSection(filter: filter)
                .padding(.top, Theme.Space.group(layout))
            if writeFailed || flow.writeFailed {
                Text("No se pudo guardar el cambio.")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Text.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .transaction(value: filter) { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    private var openArea: some View {
        TimelineView(.everyMinute) { _ in
            let days = store.dueDays
            let groups = store.openGroups(in: filter, days: days)
            let hidden = store.hiddenOverdueCount(in: filter, days: days)
            VStack(spacing: 0) {
                if hidden > 0 {
                    OverdueLink(count: hidden) { panel.select(filter: .overdue) }
                }
                if groups.isEmpty {
                    EmptyListContent(filter: filter, now: days.now)
                } else {
                    rows(groups, now: days.now)
                }
            }
        }
    }

    private func rows(_ groups: [DueGroup], now: Date) -> some View {
        ScrollViewReader { proxy in
            rowsScroll(groups, now: now)
                .onChange(of: flow.scrollTargetID, initial: true) {
                    scroll(to: flow.scrollTargetID, with: proxy)
                }
                .onChange(of: flow.drag?.gap) { _, gap in
                    reveal(gap, in: groups, with: proxy)
                }
        }
    }

    private func reveal(_ gap: Int?, in groups: [DueGroup], with proxy: ScrollViewProxy) {
        guard let gap, let id = flow.drag?.id,
              let ids = groups.first(where: { $0.priorities.contains { $0.id == id } })?.priorities.map(\.id)
        else {
            return
        }
        for index in [gap, gap - 1] where ids.indices.contains(index) {
            proxy.scrollTo(ids[index])
        }
    }

    private func scroll(to id: Priority.ID?, with proxy: ScrollViewProxy) {
        guard let id else { return }
        Task { @MainActor in
            await Task.yield()
            proxy.scrollTo(id)
            flow.scrollWasHandled(id)
        }
    }

    @ViewBuilder
    private func rowsScroll(_ groups: [DueGroup], now: Date) -> some View {
        switch layout {
        case .panel:
            ScrollView {
                groupStack(groups, now: now)
            }
            .frame(maxHeight: Theme.Row.listMaxHeight)
        case .window:
            groupStack(groups, now: now)
        }
    }

    private func groupStack(_ groups: [DueGroup], now: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                if let title = group.title {
                    groupHeader(title, isFirst: index == 0)
                }
                rowStack(group, now: now)
            }
        }
    }

    private func groupHeader(_ title: String, isFirst: Bool) -> some View {
        Text(title)
            .font(Theme.Filter.groupFont)
            .foregroundStyle(Theme.Filter.groupText)
            .padding(.horizontal, Theme.Filter.groupHorizontalPadding)
            .padding(.top, isFirst ? 0 : Theme.Filter.groupTopPadding(layout))
            .padding(.bottom, Theme.Filter.groupBottomPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    private func rowStack(_ group: DueGroup, now: Date) -> some View {
        let ids = group.priorities.map(\.id)
        let gap = ids.contains { flow.isDragging($0) } ? flow.drag?.gap : nil
        let space = "\(Self.stackSpace)-\(group.id)"
        return VStack(spacing: Theme.Row.listSpacing) {
            ForEach(Array(group.priorities.enumerated()), id: \.element.id) { index, priority in
                rowGroup(priority, now: now)
                    .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .named(space)) }) { frame in
                        frames.set(frame, for: priority.id)
                    }
                    .dropLine(at: .top, isVisible: gap == index, isListEdge: index == 0)
                    .dropLine(at: .bottom, isVisible: gap == ids.count && index == ids.count - 1, isListEdge: true)
            }
        }
        .coordinateSpace(.named(space))
        .onDrop(
            of: [UTType.utf8PlainText],
            delegate: PriorityStackDropDelegate(ids: ids, frames: frames, flow: flow)
        )
    }

    private func rowGroup(_ priority: Priority, now: Date) -> some View {
        let progress = store.subtaskProgress(of: priority.id)
        let isLeaving = flow.isLeaving(priority.id)
        let showsConfirmation = flow.isConfirming(priority.id) || isLeaving
        return VStack(spacing: 0) {
            PriorityRow(
                priority: priority,
                progress: progress,
                now: now,
                isHighlighted: flow.highlightedID == priority.id,
                isSelected: panel.openPriorityID == priority.id,
                isChecked: showsConfirmation,
                isExpanded: flow.isExpanded(priority.id),
                isDragging: flow.isDragging(priority.id),
                onToggleDone: { flow.toggleConfirmation(for: priority.id) },
                onOpen: { panel.openDetail(priority.id) },
                onToggleSubtasks: { flow.toggleSubtasks(for: priority.id) },
                onRemove: { remove(priority) },
                onDragStart: { flow.startDrag(priority.id) },
                onDragEnd: { flow.endDrag() }
            )
            if showsConfirmation {
                DoneConfirmationBar(
                    openSubtasksLabel: progress.openSubtasksLabel,
                    onCancel: { flow.cancelConfirmation() },
                    onConfirm: { flow.confirmDone(priority.id) }
                )
            }
            if flow.isExpanded(priority.id) {
                SubtaskEditor(priorityID: priority.id, style: .row)
            }
        }
        .opacity(isLeaving ? 0 : flow.isDragging(priority.id) ? Theme.Row.draggedOpacity : 1)
        .id(priority.id)
    }

    private var newPriority: some View {
        Group {
            if form.isOpen {
                NewPriorityFormView(
                    form: $form,
                    now: store.now(),
                    alertsOff: alerts?.alertsAreOff ?? false,
                    limitNotice: limitNotice,
                    onSubmit: add
                )
                .padding(.top, Theme.Space.s2)
            } else {
                NewPriorityButton { form.open(defaultDue: filter.newDue(store.dueDays)) }
            }
        }
    }

    private var limitNotice: String? {
        form.isBlockedByLimit ? store.addBlock(forDue: form.draft.dueAt) : nil
    }

    private func add() {
        do {
            guard let added = try form.submit(to: store) else { return }
            writeFailed = false
            flow.flash(added.id)
            if added.dueAt != nil {
                alerts?.dueWasSet()
            }
        } catch {
            writeFailed = true
        }
    }

    private func remove(_ priority: Priority) {
        do {
            try store.deletePriority(priority.id)
            writeFailed = false
        } catch {
            writeFailed = true
        }
    }
}
