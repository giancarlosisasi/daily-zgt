import SwiftUI

struct DueChip: View {
    let state: DueChipState
    var horizontalPadding = Theme.Due.horizontalPadding
    var laterIsPlain = false

    var body: some View {
        if laterIsPlain && state.tone == .later {
            Text(state.label)
                .font(Theme.Due.plainFont)
                .foregroundStyle(Theme.Due.plainText)
        } else {
            Text(state.label)
                .font(Theme.Due.font)
                .foregroundStyle(text)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, Theme.Due.verticalPadding)
                .background(background, in: RoundedRectangle(cornerRadius: Theme.Due.radius, style: .continuous))
        }
    }

    private var text: Color {
        switch state.tone {
        case .overdue: Theme.Due.overdueText
        case .soon: Theme.Due.soonText
        case .later: Theme.Due.laterText
        }
    }

    private var background: Color {
        switch state.tone {
        case .overdue: Theme.Due.overdueBackground
        case .soon: Theme.Due.soonBackground
        case .later: Theme.Due.laterBackground
        }
    }
}

struct RowIconButton: View {
    let icon: Icon
    let size: CGFloat
    let width: CGFloat
    let height: CGFloat
    let radius: CGFloat
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            IconView(icon: icon, size: size)
                .foregroundStyle(Theme.Text.muted)
                .frame(width: width, height: height)
        }
        .buttonStyle(GhostButtonStyle(radius: radius))
        .accessibilityLabel(label)
    }
}

struct PriorityRow: View {
    let priority: Priority
    let progress: SubtaskProgress
    let now: Date
    var isHighlighted = false
    var isSelected = false
    var isChecked = false
    var isExpanded = false
    var isDragging = false
    var todayChip: DueChipState?
    let onToggleDone: () -> Void
    let onOpen: () -> Void
    let onToggleSubtasks: () -> Void
    let onRemove: () -> Void
    let onDragStart: () -> Void
    let onDragEnd: () -> Void

    @State private var isHovering: Bool
    @State private var isTitleHovering = false
    @Environment(\.panelLayout) private var layout

    init(
        priority: Priority,
        progress: SubtaskProgress,
        now: Date,
        isHighlighted: Bool = false,
        isSelected: Bool = false,
        isChecked: Bool = false,
        isExpanded: Bool = false,
        isHoveringAtStart: Bool = false,
        isDragging: Bool = false,
        todayChip: DueChipState? = nil,
        onToggleDone: @escaping () -> Void = {},
        onOpen: @escaping () -> Void = {},
        onToggleSubtasks: @escaping () -> Void = {},
        onRemove: @escaping () -> Void = {},
        onDragStart: @escaping () -> Void = {},
        onDragEnd: @escaping () -> Void = {}
    ) {
        self.priority = priority
        self.progress = progress
        self.now = now
        self.isHighlighted = isHighlighted
        self.isSelected = isSelected
        self.isChecked = isChecked
        self.isExpanded = isExpanded
        self.isDragging = isDragging
        self.todayChip = todayChip
        self.onToggleDone = onToggleDone
        self.onOpen = onOpen
        self.onToggleSubtasks = onToggleSubtasks
        self.onRemove = onRemove
        self.onDragStart = onDragStart
        self.onDragEnd = onDragEnd
        _isHovering = State(initialValue: isHoveringAtStart)
    }

    var body: some View {
        HStack(spacing: Theme.Row.spacing) {
            HStack(spacing: Theme.Row.handleSpacing) {
                handle
                caret
            }
            PriorityCheckbox(isChecked: isChecked, action: onToggleDone)
            titleButton
        }
        .padding(.horizontal, Theme.Row.horizontalPadding)
        .overlay(alignment: .topTrailing) {
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
            .padding(.top, Theme.Row.verticalPadding + (Theme.Font.rowTitleLineHeight - Theme.Row.removeSize) / 2)
            .padding(.trailing, Theme.Row.horizontalPadding)
        }
        .frame(minHeight: layout == .window ? Theme.Row.windowMinHeight : Theme.Row.minHeight)
        .background(
            isHighlighted ? Theme.Row.highlight : isSelected ? Theme.Row.selected : Color.clear,
            in: RoundedRectangle(cornerRadius: Theme.Row.radius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Row.radius, style: .continuous)
                .fill(isHovering ? Theme.Row.hoverOverlay : Color.clear)
                .allowsHitTesting(false)
        )
        .hoverArea { isHovering = $0 }
    }

    private var handle: some View {
        let title = priority.title
        let level = priority.level
        return IconView(icon: .dragHandle, size: Theme.Row.handleIconSize)
            .foregroundStyle(Theme.Text.dim)
            .frame(width: Theme.Row.handleWidth, height: Theme.Row.handleHeight)
            .overlay(
                DragHandle(
                    payload: priority.id,
                    makeImage: { scale in DragPreview.image(title: title, level: level, scale: scale) },
                    onStart: onDragStart,
                    onEnd: onDragEnd
                )
            )
            .opacity(isHovering || isDragging ? 1 : 0)
            .accessibilityElement()
            .accessibilityLabel("Arrastrar para mover")
    }

    private var caret: some View {
        let hasSubtasks = progress.total > 0 || isExpanded
        return Button(action: onToggleSubtasks) {
            IconView(icon: .caretRight, size: Theme.Row.caretIconSize)
                .foregroundStyle(Theme.Text.dim)
                .rotationEffect(.degrees(isExpanded ? Theme.MotionShape.caretOpenDegrees : 0))
                .frame(width: Theme.Row.caretWidth, height: Theme.Row.caretHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(hasSubtasks ? 1 : 0)
        .disabled(!hasSubtasks)
        .accessibilityHidden(!hasSubtasks)
        .accessibilityLabel("Subtareas")
        .accessibilityValue(isExpanded ? "expandido" : "colapsado")
    }

    private var titleButton: some View {
        VStack(alignment: .leading, spacing: Theme.Row.titleSpacing) {
            SelectableTitle(
                text: priority.title,
                isUnderlined: isTitleHovering,
                maxLines: Theme.Row.titleMaxLines,
                onOpen: onOpen
            )
            .padding(.trailing, Theme.Row.removeSize + Theme.Row.spacing)
            meta
        }
        .padding(.vertical, Theme.Row.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .hoverArea { isTitleHovering = $0 }
        .linkCursor()
    }

    private var meta: some View {
        HStack(spacing: Theme.Row.metaSpacing) {
            LevelBars(level: priority.level)
            if let chip = DueChipState.make(due: priority.dueAt, now: now) {
                DueChip(state: chip, laterIsPlain: true)
            }
            if let todayChip {
                DueChip(state: todayChip)
            }
            if let ratio = progress.ratioLabel {
                Text(ratio)
            }
            if PriorityNote.isPresent(priority.note) {
                IconView(icon: .note, size: Theme.Row.noteIconSize)
                    .accessibilityElement()
                    .accessibilityLabel("Tiene notas")
            }
        }
        .font(Theme.Font.meta)
        .foregroundStyle(Theme.Text.muted)
        .frame(minHeight: Theme.Row.metaHeight)
    }
}
