import SwiftUI

struct EmptyListContent: View {
    let list: PriorityList
    let now: Date

    @Environment(AppStore.self) private var store

    var body: some View {
        let cutoff = DoneWindow.cutoff(now: now)
        if ((try? store.donePriorities(in: list, after: cutoff)) ?? []).isEmpty {
            Text("Nada pendiente en esta lista.")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.EmptyList.text)
                .padding(.vertical, Theme.EmptyList.verticalPadding)
                .padding(.horizontal, Theme.EmptyList.horizontalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(spacing: Theme.AllDone.spacing) {
                AllDoneCheck()
                Text("Todo listo en esta lista")
                    .font(Theme.Font.bodyStrong)
                    .foregroundStyle(Theme.Text.primary)
            }
            .padding(.top, Theme.AllDone.topPadding)
            .padding(.bottom, Theme.AllDone.bottomPadding)
            .padding(.horizontal, Theme.AllDone.horizontalPadding)
            .frame(maxWidth: .infinity)
        }
    }
}

struct PriorityListView: View {
    let list: PriorityList

    @Environment(AppStore.self) private var store
    @Environment(PanelState.self) private var panel
    @Environment(AlertCoordinator.self) private var alerts: AlertCoordinator?
    @State private var writeFailed = false
    @Environment(\.motionPolicy) private var motion
    @State private var form = NewPriorityForm()

    private var flow: PriorityFlow { panel.priorityFlow }

    var body: some View {
        VStack(spacing: Theme.Row.sectionSpacing) {
            openArea
            newPriority
            DoneSection(list: list)
            if writeFailed || flow.writeFailed {
                Text("No se pudo guardar el cambio.")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Text.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .fadeIn(on: list)
    }

    private var openArea: some View {
        let open = store.openPriorities(in: list)
        let entryEvents = TodayEntry.events(for: list, in: store)
        return Group {
            if open.isEmpty {
                TimelineView(.everyMinute) { _ in
                    EmptyListContent(list: list, now: store.now())
                }
                .motionTransition(.fadeIn)
            } else {
                TimelineView(.everyMinute) { _ in
                    let now = store.now()
                    rows(open, chips: TodayEntry.chips(events: entryEvents, now: now), now: now)
                }
            }
        }
        .motion(.fade, value: open.isEmpty)
    }

    private func rows(_ open: [Priority], chips: [Priority.ID: DueChipState], now: Date) -> some View {
        ScrollViewReader { proxy in
            rowsScroll(open, chips: chips, now: now)
                .onChange(of: flow.scrollTargetID, initial: true) {
                    scroll(to: flow.scrollTargetID, with: proxy)
                }
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

    private func rowsScroll(_ open: [Priority], chips: [Priority.ID: DueChipState], now: Date) -> some View {
        ScrollView {
            VStack(spacing: Theme.Row.listSpacing) {
                ForEach(open) { priority in
                    rowGroup(priority, chip: chips[priority.id], now: now)
                }
            }
            .motion(.rowIn, value: open.map(\.id))
        }
        .frame(maxHeight: Theme.Row.listMaxHeight)
    }

    private func rowGroup(_ priority: Priority, chip: DueChipState?, now: Date) -> some View {
        let progress = store.subtaskProgress(of: priority.id)
        let isLeaving = flow.isLeaving(priority.id)
        let showsConfirmation = flow.isConfirming(priority.id) || isLeaving
        return VStack(spacing: 0) {
            PriorityRow(
                priority: priority,
                progress: progress,
                now: now,
                isHighlighted: flow.highlightedID == priority.id,
                isChecked: showsConfirmation,
                isExpanded: flow.isExpanded(priority.id),
                todayChip: chip,
                onToggleDone: { flow.toggleConfirmation(for: priority.id) },
                onOpen: { panel.openDetail(priority.id) },
                onToggleSubtasks: { flow.toggleSubtasks(for: priority.id) },
                onRemove: { remove(priority) }
            )
            if showsConfirmation {
                DoneConfirmationBar(
                    openSubtasksLabel: progress.openSubtasksLabel,
                    onCancel: { flow.cancelConfirmation() },
                    onConfirm: { flow.confirmDone(priority.id, leaving: motion.leaveDelay) }
                )
                .motionTransition(.rowIn)
            }
            if flow.isExpanded(priority.id) {
                SubtaskEditor(priorityID: priority.id, style: .row)
                    .motionTransition(.rowIn)
            }
        }
        .motion(.rowIn, value: showsConfirmation)
        .motion(.rowIn, value: flow.isExpanded(priority.id))
        .offset(x: isLeaving ? Theme.MotionShape.rowOutOffset : 0)
        .opacity(isLeaving ? 0 : 1)
        .motion(.rowOut, value: isLeaving)
        .motionTransition(.rowIn)
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
                .motionTransition(.rowIn)
            } else {
                NewPriorityButton { form.open() }
                    .motionTransition(.rowIn)
            }
        }
        .motion(.rowIn, value: form.isOpen)
    }

    private var limitNotice: String? {
        list == .today && form.isBlockedByLimit ? store.todayAddBlock() : nil
    }

    private func add() {
        do {
            guard let added = try form.submit(to: store, list: list) else { return }
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
