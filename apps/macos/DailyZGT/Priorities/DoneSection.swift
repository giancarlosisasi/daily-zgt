import SwiftUI

struct DoneCheckIcon: View {
    var body: some View {
        IconView(icon: .check, size: Theme.DoneSection.checkSize)
            .foregroundStyle(Theme.DoneSection.checkColor)
            .accessibilityElement()
            .accessibilityLabel("Hecha")
    }
}

struct DoneRow: View {
    let priority: Priority
    let onRestore: () -> Void
    let onRemove: () -> Void
    let leadingPadding: CGFloat

    @State private var isHovering: Bool

    init(
        priority: Priority,
        isHoveringAtStart: Bool = false,
        leadingPadding: CGFloat = Theme.DoneSection.rowLeadingPadding,
        onRestore: @escaping () -> Void = {},
        onRemove: @escaping () -> Void = {}
    ) {
        self.priority = priority
        self.onRestore = onRestore
        self.onRemove = onRemove
        self.leadingPadding = leadingPadding
        _isHovering = State(initialValue: isHoveringAtStart)
    }

    var body: some View {
        HStack(spacing: Theme.DoneSection.rowSpacing) {
            DoneCheckIcon()
            Text(priority.title)
                .font(Theme.Font.body)
                .strikethrough(true, color: Theme.DoneSection.title)
                .foregroundStyle(Theme.DoneSection.title)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            Button(action: onRestore) {
                HStack(spacing: Theme.DoneSection.restoreSpacing) {
                    IconView(icon: .arrowBack, size: Theme.DoneSection.restoreIconSize)
                    Text("Regresar")
                        .font(Theme.DoneSection.restoreFont)
                }
                .foregroundStyle(Theme.DoneSection.restoreText)
                .padding(.horizontal, Theme.DoneSection.restorePadding)
                .frame(height: Theme.DoneSection.restoreHeight)
            }
            .buttonStyle(KeyButtonStyle(role: .graphite, radius: Theme.DoneSection.restoreRadius))
            .fixedSize()
            RowIconButton(
                icon: .trash,
                size: Theme.Row.removeIconSize,
                width: Theme.Row.removeSize,
                height: Theme.Row.removeSize,
                radius: Theme.Row.removeRadius,
                label: "Quitar",
                action: onRemove
            )
            .opacity(isHovering ? 1 : 0)
        }
        .padding(.leading, leadingPadding)
        .padding(.trailing, Theme.DoneSection.rowTrailingPadding)
        .frame(minHeight: Theme.DoneSection.rowMinHeight)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Row.radius, style: .continuous)
                .fill(isHovering ? Theme.Row.hoverOverlay : Color.clear)
                .allowsHitTesting(false)
        )
        .motion(.fade, value: isHovering)
        .onHover { isHovering = $0 }
    }
}

struct HistoryRow: View {
    let count: Int
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: Theme.History.rowSpacing) {
                Text(DoneSection.historyTitle)
                    .font(Theme.History.rowFont)
                    .foregroundStyle(Theme.Text.muted)
                Spacer(minLength: 0)
                Text("\(count)")
                    .font(Theme.History.countFont)
                    .foregroundStyle(Theme.History.countText)
                IconView(icon: .caretRight, size: Theme.History.caretSize)
                    .foregroundStyle(Theme.History.countText)
            }
            .padding(.leading, Theme.History.rowLeadingPadding)
            .padding(.trailing, Theme.History.rowTrailingPadding)
            .frame(height: Theme.History.rowHeight)
        }
        .buttonStyle(GhostButtonStyle(radius: Theme.History.rowRadius))
        .accessibilityLabel(DoneSection.historyTitle)
        .accessibilityValue("\(count)")
    }
}

struct DoneSection: View {
    let list: PriorityList

    @Environment(AppStore.self) private var store

    static let historyTitle = "Historial"

    static func headerTitle(count: Int) -> String {
        "Hechas (\(count))"
    }

    var body: some View {
        TimelineView(.everyMinute) { _ in
            DoneSectionContent(list: list, now: store.now())
        }
    }
}

struct DoneSectionContent: View {
    let list: PriorityList
    let now: Date

    @Environment(AppStore.self) private var store
    @Environment(PanelState.self) private var panel

    var body: some View {
        let cutoff = DoneWindow.cutoff(now: now)
        let recent = (try? store.donePriorities(in: list, after: cutoff)) ?? []
        let olderCount = (try? store.doneCount(in: list, atOrBefore: cutoff)) ?? 0
        if !recent.isEmpty || olderCount > 0 {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Theme.DoneSection.divider)
                    .frame(height: Theme.DoneSection.dividerHeight)
                VStack(spacing: Theme.DoneSection.spacing) {
                    header(count: recent.count)
                    if panel.isDoneOpen {
                        VStack(spacing: Theme.DoneSection.spacing) {
                            ForEach(recent) { priority in
                                DoneRow(
                                    priority: priority,
                                    onRestore: { panel.priorityFlow.restore(priority.id) },
                                    onRemove: { panel.priorityFlow.delete(priority.id) }
                                )
                            }
                            if olderCount > 0 {
                                HistoryRow(count: olderCount, onOpen: { panel.openHistory() })
                            }
                        }
                        .motionTransition(.rowIn)
                    }
                }
                .motion(.rowIn, value: panel.isDoneOpen)
                .padding(.top, Theme.DoneSection.topPadding)
            }
        }
    }

    private func header(count: Int) -> some View {
        Button(action: { panel.toggleDone() }) {
            HStack(spacing: Theme.DoneSection.headerSpacing) {
                IconView(icon: .caretRight, size: Theme.DoneSection.caretSize)
                    .rotationEffect(.degrees(panel.isDoneOpen ? Theme.MotionShape.caretOpenDegrees : 0))
                    .motion(.caret, value: panel.isDoneOpen)
                Text(DoneSection.headerTitle(count: count))
                    .font(Theme.DoneSection.headerFont)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.Text.muted)
            .padding(.horizontal, Theme.DoneSection.headerPadding)
            .frame(height: Theme.DoneSection.headerHeight)
        }
        .buttonStyle(GhostButtonStyle(radius: Theme.DoneSection.headerRadius))
        .accessibilityValue(panel.isDoneOpen ? "expandido" : "colapsado")
    }
}
