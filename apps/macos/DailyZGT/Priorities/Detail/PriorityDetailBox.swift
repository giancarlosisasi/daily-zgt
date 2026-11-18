import SwiftUI

struct PropertyMenuButton<Value: Hashable, Label: View, OptionLabel: View>: View {
    let title: String
    let options: [Value]
    let selection: Value
    let onSelect: (Value) -> Void
    @ViewBuilder let label: () -> Label
    @ViewBuilder let optionLabel: (Value) -> OptionLabel

    @State private var isOpen = false

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            HStack(spacing: Theme.Detail.valueSpacing) {
                label()
                IconView(icon: .caretRight, size: Theme.Detail.valueCaretSize)
                    .rotationEffect(.degrees(Theme.MotionShape.caretOpenDegrees))
                    .foregroundStyle(Theme.Detail.valueDim)
            }
            .font(Theme.Detail.valueFont)
            .foregroundStyle(Theme.Detail.valueText)
            .padding(.horizontal, Theme.Detail.valuePadding)
            .frame(height: Theme.Detail.valueHeight)
        }
        .buttonStyle(.ghost)
        .fixedSize()
        .accessibilityLabel(title)
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            VStack(spacing: 0) {
                ForEach(options, id: \.self) { option in
                    Button {
                        onSelect(option)
                        isOpen = false
                    } label: {
                        HStack(spacing: Theme.Detail.valueSpacing) {
                            optionLabel(option)
                            Spacer(minLength: 0)
                        }
                        .font(Theme.Detail.valueFont)
                        .foregroundStyle(Theme.Detail.valueText)
                        .padding(.horizontal, Theme.Detail.valuePadding)
                        .frame(height: Theme.Detail.menuRowHeight)
                        .background(
                            option == selection ? Theme.Detail.menuSelected : Color.clear,
                            in: RoundedRectangle(cornerRadius: Theme.Ghost.radius, style: .continuous)
                        )
                    }
                    .buttonStyle(.ghost)
                    .accessibilityAddTraits(option == selection ? .isSelected : [])
                }
            }
            .padding(Theme.Detail.menuPadding)
            .frame(width: Theme.Detail.menuWidth)
            .background(Theme.DatePopover.background)
            .environment(\.colorScheme, .dark)
        }
    }
}

struct PriorityDetailBox: View {
    let priority: Priority
    let now: Date
    var alertsOff = false
    var dueNotice: String?
    let onLevel: (PriorityLevel) -> Void
    let onDue: (Date?) -> Void
    var onRepeat: (RepeatRule) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Detail.propertySpacing) {
            row("Prioridad") {
                PropertyMenuButton(
                    title: "Prioridad",
                    options: PriorityLevel.allCases,
                    selection: priority.level,
                    onSelect: onLevel,
                    label: { levelLabel(priority.level) },
                    optionLabel: { levelLabel($0) }
                )
            }
            row("Fecha límite") {
                DueDateField(
                    dueAt: Binding(get: { priority.dueAt }, set: { onDue($0) }),
                    now: now,
                    alertsOff: alertsOff
                )
            }
            if let dueNotice {
                LimitNotice(text: dueNotice)
                    .padding(.leading, Theme.Detail.labelWidth)
            }
            row("Repetir") {
                PropertyMenuButton(
                    title: "Repetir",
                    options: RepeatRule.allCases,
                    selection: priority.repeatRule,
                    onSelect: onRepeat,
                    label: { Text(PriorityDetailLabels.repeatValue(priority.repeatRule)) },
                    optionLabel: { Text(PriorityDetailLabels.repeatValue($0)) }
                )
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
                .foregroundStyle(Theme.Detail.valueText)
                .padding(.horizontal, Theme.Detail.valuePadding)
            }
        }
    }

    private var showsAlertsOff: Bool {
        alertsOff && priority.dueAt != nil
    }

    private func levelLabel(_ level: PriorityLevel) -> some View {
        HStack(spacing: Theme.Detail.valueSpacing) {
            LevelBars(level: level)
            Text(level.label)
        }
    }

    private func row(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(Theme.Detail.labelFont)
                .foregroundStyle(Theme.Detail.labelText)
                .lineLimit(1)
                .frame(width: Theme.Detail.labelWidth, alignment: .leading)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: Theme.Detail.propertyHeight)
    }
}
