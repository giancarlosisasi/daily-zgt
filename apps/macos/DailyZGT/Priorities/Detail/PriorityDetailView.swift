import SwiftUI

struct MarkDoneButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Detail.markDoneSpacing) {
                IconView(icon: .check, size: Theme.Detail.markDoneIconSize)
                Text("Marcar como hecha")
                    .font(Theme.Detail.markDoneFont)
            }
            .foregroundStyle(Theme.Detail.markDoneText)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Detail.markDoneHeight)
        }
        .buttonStyle(KeyButtonStyle(role: .graphite, radius: Theme.Detail.markDoneRadius))
    }
}

struct PriorityDetailView: View {
    let priority: Priority
    var titleShowsEditState = false

    @Environment(AppStore.self) private var store
    @Environment(PanelState.self) private var panel
    @Environment(AlertCoordinator.self) private var alerts: AlertCoordinator?
    @State private var writeFailed = false
    @State private var moveWasBlocked = false

    private var listNotice: String? {
        moveWasBlocked && priority.list == .week ? store.todayAddBlock() : nil
    }

    private var entryEvents: [PriorityEvent] {
        priority.list == .today ? ((try? store.events(of: priority.id)) ?? []) : []
    }

    private var flow: PriorityFlow { panel.priorityFlow }
    private var actions: PriorityDetailActions { PriorityDetailActions(store: store, id: priority.id) }

    var body: some View {
        let progress = store.subtaskProgress(of: priority.id)
        VStack(alignment: .leading, spacing: Theme.Detail.spacing) {
            PriorityDetailHeader(
                backLabel: priority.list.title,
                onBack: { panel.closeDetail() },
                onDelete: { flow.delete(priority.id) }
            )
            VStack(alignment: .leading, spacing: Theme.Detail.headSpacing) {
                PriorityDetailTitleField(title: priority.title, showsEditState: titleShowsEditState) { draft in
                    attempt { try actions.commitTitle(draft) } ?? priority.title
                }
                TimelineView(.everyMinute) { _ in
                    PriorityDetailChips(
                        priority: priority,
                        progress: progress,
                        now: store.now(),
                        todayChip: TodayEntry.chip(events: entryEvents, now: store.now())
                    )
                }
            }
            PriorityDetailBox(
                priority: priority,
                now: store.now(),
                alertsOff: alerts?.alertsAreOff ?? false,
                listNotice: listNotice,
                onLevel: { level in attempt { try actions.setLevel(level) } },
                onDue: { due in
                    if attempt({ try actions.setDue(due) }) != nil, due != nil {
                        alerts?.dueWasSet()
                    }
                },
                onList: { list in
                    switch attempt({ try actions.setList(list) }) {
                    case .moved:
                        moveWasBlocked = false
                        panel.select(scope: list)
                    case .blocked:
                        moveWasBlocked = true
                    case nil:
                        break
                    }
                },
                onRepeat: { rule in attempt { try actions.setRepeat(rule) } }
            )
            PriorityDetailSubtasksSection(priority: priority)
            PriorityDetailNoteSection(priority: priority)
            doneControl(progress)
            Text(PriorityDetailLabels.created(priority.createdAt, now: store.now()))
                .font(Theme.Font.meta)
                .foregroundStyle(Theme.Detail.created)
            if writeFailed || flow.writeFailed {
                Text("No se pudo guardar el cambio.")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Text.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func doneControl(_ progress: SubtaskProgress) -> some View {
        Group {
            if priority.isDone {
                EmptyView()
            } else if flow.isConfirming(priority.id) {
                DoneConfirmationBar(
                    openSubtasksLabel: progress.openSubtasksLabel,
                    usesRowMargins: false,
                    onCancel: { flow.cancelConfirmation() },
                    onConfirm: { flow.confirmDone(priority.id) }
                )
                .motionTransition(.rowIn)
            } else {
                MarkDoneButton { flow.toggleConfirmation(for: priority.id) }
                    .motionTransition(.rowIn)
            }
        }
        .motion(.rowIn, value: flow.isConfirming(priority.id))
    }

    @discardableResult
    private func attempt<Value>(_ write: () throws -> Value) -> Value? {
        do {
            let value = try write()
            writeFailed = false
            return value
        } catch {
            writeFailed = true
            return nil
        }
    }
}
