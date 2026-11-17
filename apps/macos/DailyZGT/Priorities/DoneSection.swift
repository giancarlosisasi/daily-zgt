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
    let onOpen: () -> Void
    let onRestore: () -> Void
    let onRemove: () -> Void
    let leadingPadding: CGFloat
    let look: TitleLook
    let doneTime: String?

    @State private var isHovering: Bool
    @State private var isTitleHovering = false

    init(
        priority: Priority,
        isHoveringAtStart: Bool = false,
        leadingPadding: CGFloat = Theme.DoneSection.rowLeadingPadding,
        look: TitleLook = .done,
        doneTime: String? = nil,
        onOpen: @escaping () -> Void = {},
        onRestore: @escaping () -> Void = {},
        onRemove: @escaping () -> Void = {}
    ) {
        self.priority = priority
        self.onOpen = onOpen
        self.onRestore = onRestore
        self.onRemove = onRemove
        self.leadingPadding = leadingPadding
        self.look = look
        self.doneTime = doneTime
        _isHovering = State(initialValue: isHoveringAtStart)
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.DoneSection.rowSpacing) {
            DoneCheckIcon()
                .frame(height: Theme.Font.rowTitleLineHeight)
            SelectableTitle(
                text: priority.title,
                isUnderlined: isTitleHovering,
                look: look,
                maxLines: Theme.Row.titleMaxLines,
                onOpen: onOpen
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
            .hoverArea { isTitleHovering = $0 }
            .linkCursor()
            if let doneTime {
                Text(doneTime)
                    .font(Theme.DoneSection.timeFont)
                    .foregroundStyle(Theme.DoneSection.timeText)
                    .fixedSize()
                    .frame(height: Theme.Font.rowTitleLineHeight)
            }
            Button(action: onRestore) {
                HStack(spacing: Theme.DoneSection.restoreSpacing) {
                    IconView(icon: .arrowBack, size: Theme.DoneSection.restoreIconSize)
                    Text("Regresar")
                        .font(Theme.DoneSection.restoreFont)
                }
                .foregroundStyle(isHovering ? Theme.DoneSection.restoreHoverText : Theme.DoneSection.restoreText)
                .padding(.horizontal, Theme.DoneSection.restorePadding)
                .frame(height: Theme.DoneSection.restoreHeight)
            }
            .buttonStyle(GhostButtonStyle(radius: Theme.DoneSection.restoreRadius))
            .fixedSize()
            .frame(height: Theme.Font.rowTitleLineHeight)
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
            .frame(height: Theme.Font.rowTitleLineHeight)
        }
        .padding(.leading, leadingPadding)
        .padding(.trailing, Theme.DoneSection.rowTrailingPadding)
        .padding(.vertical, Theme.DoneSection.rowVerticalPadding)
        .frame(minHeight: Theme.DoneSection.rowMinHeight)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Row.radius, style: .continuous)
                .fill(isHovering ? Theme.Row.hoverOverlay : Color.clear)
                .allowsHitTesting(false)
        )
        .hoverArea { isHovering = $0 }
    }
}

struct HistoryLink: View {
    let count: Int
    let onOpen: () -> Void

    static func title(count: Int) -> String {
        "Ver historial (\(count))"
    }

    var body: some View {
        Button(action: onOpen) {
            Text(Self.title(count: count))
                .font(Theme.DoneSection.historyLinkFont)
                .foregroundStyle(Theme.DoneSection.historyLinkText)
                .padding(.horizontal, Theme.DoneSection.headerPadding)
                .frame(height: Theme.DoneSection.historyLinkHeight)
        }
        .buttonStyle(GhostButtonStyle(radius: Theme.DoneSection.headerRadius))
        .linkCursor()
        .accessibilityLabel(DoneSection.historyTitle)
        .accessibilityValue("\(count)")
    }
}

struct DoneSection: View {
    let filter: DueFilter

    @Environment(AppStore.self) private var store

    static let historyTitle = "Historial"
    static let headerTitle = "Hechas"

    var body: some View {
        TimelineView(.everyMinute) { _ in
            DoneSectionContent(filter: filter, now: store.now())
        }
    }
}

struct DoneSectionContent: View {
    let filter: DueFilter
    let now: Date

    @Environment(AppStore.self) private var store
    @Environment(PanelState.self) private var panel

    var body: some View {
        let days = DueDays(now: now)
        let recent = store.donePriorities(in: filter, days: days)
        let olderCount = store.olderDonePriorities(outside: filter, days: days).count
        if !recent.isEmpty || olderCount > 0 {
            VStack(alignment: .leading, spacing: Theme.DoneSection.spacing) {
                header(count: recent.count)
                if panel.isDoneOpen {
                    ForEach(recent) { priority in
                        DoneRow(
                            priority: priority,
                            onOpen: { panel.openDetail(priority.id) },
                            onRestore: { panel.priorityFlow.restore(priority.id) },
                            onRemove: { panel.priorityFlow.delete(priority.id) }
                        )
                    }
                    if olderCount > 0 {
                        HistoryLink(count: olderCount, onOpen: { panel.openHistory() })
                            .padding(.leading, Theme.DoneSection.rowLeadingPadding - Theme.DoneSection.headerPadding)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func header(count: Int) -> some View {
        Button(action: { panel.toggleDone() }) {
            HStack(spacing: Theme.DoneSection.headerSpacing) {
                IconView(icon: .caretRight, size: Theme.DoneSection.caretSize)
                    .rotationEffect(.degrees(panel.isDoneOpen ? Theme.MotionShape.caretOpenDegrees : 0))
                Text(DoneSection.headerTitle)
                    .font(Theme.DoneSection.headerFont)
                Text("\(count)")
                    .font(Theme.DoneSection.countFont)
                    .foregroundStyle(Theme.DoneSection.countText)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.Text.muted)
            .padding(.horizontal, Theme.DoneSection.headerPadding)
            .frame(height: Theme.DoneSection.headerHeight)
        }
        .buttonStyle(GhostButtonStyle(radius: Theme.DoneSection.headerRadius))
        .accessibilityLabel(DoneSection.headerTitle)
        .accessibilityValue("\(count), \(panel.isDoneOpen ? "expandido" : "colapsado")")
    }
}
