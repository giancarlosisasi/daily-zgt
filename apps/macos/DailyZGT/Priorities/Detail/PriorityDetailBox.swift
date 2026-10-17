import SwiftUI

struct PriorityDetailBox: View {
    let priority: Priority
    let now: Date
    var alertsOff = false
    var listNotice: String?
    let onLevel: (PriorityLevel) -> Void
    let onDue: (Date?) -> Void
    let onList: (PriorityList) -> Void
    var onRepeat: (RepeatRule) -> Void = { _ in }

    var body: some View {
        VStack(spacing: Theme.Detail.boxSpacing) {
            row("Prioridad") {
                LevelSegmentedPicker(selection: Binding(get: { priority.level }, set: { onLevel($0) }))
            }
            row("Fecha límite") {
                DueDateField(dueAt: Binding(get: { priority.dueAt }, set: { onDue($0) }), now: now)
            }
            row("Lista") {
                ListSegmentedPicker(selection: Binding(get: { priority.list }, set: { onList($0) }))
            }
            if let listNotice {
                LimitNotice(text: listNotice)
                    .padding(.leading, Theme.Detail.labelWidth + Theme.Detail.boxSpacing)
            }
            row("Repetir") {
                RepeatSegmentedPicker(selection: Binding(get: { priority.repeatRule }, set: { onRepeat($0) }))
            }
            row("Alerta") {
                HStack(spacing: Theme.Detail.alertSpacing) {
                    IconView(icon: showsAlertsOff ? .bellSlash : .bell, size: Theme.Detail.alertIconSize)
                    if showsAlertsOff {
                        AlertsOffNotice()
                    } else {
                        Text(PriorityDetailLabels.alert(due: priority.dueAt))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .font(Theme.Detail.valueFont)
                .foregroundStyle(Theme.Text.secondary)
            }
        }
        .padding(Theme.Detail.boxPadding)
        .background(
            Theme.Detail.boxBackground,
            in: RoundedRectangle(cornerRadius: Theme.Detail.boxRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Detail.boxRadius, style: .continuous)
                .strokeBorder(Theme.Detail.boxBorder, lineWidth: 1)
        )
    }

    private var showsAlertsOff: Bool {
        alertsOff && priority.dueAt != nil
    }

    private func row(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: Theme.Detail.boxSpacing) {
            Text(label)
                .font(Theme.Font.meta)
                .foregroundStyle(Theme.Text.muted)
                .lineLimit(1)
                .frame(width: Theme.Detail.labelWidth, alignment: .leading)
            content()
                .frame(maxWidth: .infinity)
        }
    }
}

struct ListSegmentedPicker: View {
    @Binding var selection: PriorityList

    var body: some View {
        HStack(spacing: Theme.Segmented.trackSpacing) {
            ForEach(PriorityList.allCases, id: \.self) { list in
                ListSegmentButton(list: list, isSelected: selection == list) {
                    selection = list
                }
            }
        }
        .padding(Theme.Segmented.trackPadding)
        .background(
            Theme.NewPriority.inputBackground,
            in: RoundedRectangle(cornerRadius: Theme.NewPriority.segmentTrackRadius, style: .continuous)
        )
        .motion(.fade, value: selection)
    }
}

private struct ListSegmentButton: View {
    let list: PriorityList
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            SegmentFace(isSelected: isSelected, radius: Theme.NewPriority.segmentRadius) {
                Text(list.title)
                    .font(Theme.Font.label)
                    .foregroundStyle(foreground)
                    .frame(maxWidth: .infinity)
                    .frame(height: Theme.NewPriority.segmentHeight)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var foreground: Color {
        if isSelected { return Theme.Segmented.selectedText }
        return isHovering ? Theme.Segmented.hoverText : Theme.Segmented.unselectedText
    }
}
