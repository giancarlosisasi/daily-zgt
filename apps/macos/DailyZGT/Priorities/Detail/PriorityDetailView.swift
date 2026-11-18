import SwiftUI

struct DetailKeyButton: View {
    let icon: Icon
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Detail.markDoneSpacing) {
                IconView(icon: icon, size: Theme.Detail.markDoneIconSize)
                Text(title)
                    .font(Theme.Detail.markDoneFont)
            }
            .foregroundStyle(Theme.Detail.markDoneText)
            .padding(.horizontal, Theme.Detail.markDonePadding)
            .frame(height: Theme.Detail.markDoneHeight)
        }
        .buttonStyle(KeyButtonStyle(role: .graphite, radius: Theme.Detail.markDoneRadius))
        .fixedSize()
    }
}

struct MarkDoneButton: View {
    let action: () -> Void

    var body: some View {
        DetailKeyButton(icon: .check, title: "Marcar como hecha", action: action)
    }
}

struct RestoreDoneButton: View {
    let action: () -> Void

    var body: some View {
        DetailKeyButton(icon: .arrowBack, title: "Regresar", action: action)
    }
}

struct PriorityDetailView: View {
    let priority: Priority
    var titleShowsEditState = false

    @Environment(AppStore.self) private var store
    @Environment(PanelState.self) private var panel
    @Environment(AlertCoordinator.self) private var alerts: AlertCoordinator?
    @Environment(\.panelLayout) private var layout
    @State private var writeFailed = false
    @State private var dueNotice: String?

    private var flow: PriorityFlow { panel.priorityFlow }
    private var actions: PriorityDetailActions { PriorityDetailActions(store: store, id: priority.id) }

    var body: some View {
        let progress = store.subtaskProgress(of: priority.id)
        VStack(alignment: .leading, spacing: Theme.Space.group(layout)) {
            VStack(alignment: .leading, spacing: Theme.Detail.headSpacing) {
                PriorityDetailHeader(
                    backLabel: DueFilterLabels.title(panel.filter, store.dueDays),
                    onBack: { panel.backFromDetail() },
                    onDelete: { flow.delete(priority.id) }
                ) {
                    PriorityDetailTitleField(title: priority.title, showsEditState: titleShowsEditState) { draft in
                        attempt { try actions.commitTitle(draft) } ?? priority.title
                    }
                    .disabled(priority.isDone)
                }
                if PriorityDetailChips.showsAny(priority: priority, now: store.now()) {
                    TimelineView(.everyMinute) { _ in
                        PriorityDetailChips(priority: priority, progress: progress, now: store.now())
                    }
                }
            }
            TimelineView(.everyMinute) { _ in
                PriorityDetailBox(
                    priority: priority,
                    now: store.now(),
                    alertsOff: alerts?.alertsAreOff ?? false,
                    dueNotice: dueNotice,
                    onLevel: { level in attempt { try actions.setLevel(level) } },
                    onDue: { due in
                        switch attempt({ try actions.setDue(due) }) {
                        case .saved:
                            dueNotice = nil
                            if due != nil {
                                alerts?.dueWasSet()
                            }
                        case let .blocked(message):
                            dueNotice = message
                        case nil:
                            break
                        }
                    },
                    onRepeat: { rule in attempt { try actions.setRepeat(rule) } }
                )
            }
            .disabled(priority.isDone)
            PriorityDetailSubtasksSection(priority: priority, progress: progress)
                .disabled(priority.isDone)
            PriorityDetailNoteSection(priority: priority)
                .disabled(priority.isDone)
            VStack(alignment: .leading, spacing: Theme.Detail.headSpacing) {
                doneControl(progress)
                if writeFailed || flow.writeFailed {
                    Text("No se pudo guardar el cambio.")
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Text.muted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var createdLabel: some View {
        Text(PriorityDetailLabels.created(priority.createdAt, now: store.now()))
            .font(Theme.Font.meta)
            .foregroundStyle(Theme.Detail.created)
    }

    @ViewBuilder
    private func doneControl(_ progress: SubtaskProgress) -> some View {
        if !priority.isDone, flow.isConfirming(priority.id) {
            VStack(alignment: .leading, spacing: Theme.Detail.headSpacing) {
                DoneConfirmationBar(
                    openSubtasksLabel: progress.openSubtasksLabel,
                    usesRowMargins: false,
                    onCancel: { flow.cancelConfirmation() },
                    onConfirm: { flow.confirmDone(priority.id) }
                )
                createdLabel
            }
        } else {
            HStack(spacing: Theme.Detail.headSpacing) {
                if priority.isDone {
                    RestoreDoneButton { panel.restoreFromDetail() }
                } else {
                    MarkDoneButton { flow.toggleConfirmation(for: priority.id) }
                }
                Spacer(minLength: 0)
                createdLabel
            }
            .padding(.bottom, Theme.Key.sideHeight)
        }
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
