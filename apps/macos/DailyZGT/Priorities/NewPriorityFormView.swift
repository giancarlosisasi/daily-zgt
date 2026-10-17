import AppKit
import SwiftUI

struct NewPriorityButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.NewPriority.buttonSpacing) {
                IconView(icon: .plus, size: Theme.NewPriority.buttonIconSize)
                Text("Nueva prioridad")
                Spacer(minLength: 0)
            }
            .font(Theme.Font.body)
            .foregroundStyle(Theme.Text.ghost)
            .padding(.horizontal, Theme.NewPriority.buttonPadding)
            .frame(height: Theme.NewPriority.buttonHeight)
        }
        .buttonStyle(GhostButtonStyle(radius: Theme.NewPriority.buttonRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.NewPriority.buttonRadius, style: .continuous)
                .strokeBorder(Theme.NewPriority.buttonBorder, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .allowsHitTesting(false)
        )
    }
}

struct LevelSegmentedPicker: View {
    @Binding var selection: PriorityLevel

    var body: some View {
        HStack(spacing: Theme.Segmented.trackSpacing) {
            ForEach(PriorityLevel.allCases, id: \.self) { level in
                LevelSegmentButton(level: level, isSelected: selection == level) {
                    selection = level
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

private struct LevelSegmentButton: View {
    let level: PriorityLevel
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            SegmentFace(isSelected: isSelected, radius: Theme.NewPriority.segmentRadius) {
                HStack(spacing: Theme.NewPriority.segmentSpacing) {
                    LevelBars(level: level)
                    Text(level.label)
                }
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

struct FormInputChrome: ViewModifier {
    let height: CGFloat
    let radius: CGFloat
    var isFocused = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .frame(height: height)
            .background(Theme.NewPriority.inputBackground, in: shape)
            .overlay(shape.strokeBorder(Theme.NewPriority.inputBorder, lineWidth: 1))
            .overlay {
                if isFocused {
                    shape.strokeBorder(Theme.Accent.focusRing, lineWidth: Theme.Accent.focusRingWidth)
                }
            }
    }
}

private struct FormActionButton: View {
    let title: String
    let padding: CGFloat
    var isPrimary = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(isPrimary ? Theme.Font.labelStrong : Theme.Font.label)
                .padding(.horizontal, padding)
                .frame(height: Theme.NewPriority.actionHeight)
        }
        .buttonStyle(KeyButtonStyle(role: isPrimary ? .primary : .graphite, radius: Theme.NewPriority.actionRadius))
    }
}

struct DateFieldPicker: NSViewRepresentable {
    @Binding var date: Date

    @MainActor
    final class Coordinator: NSObject {
        var date: Binding<Date>

        init(date: Binding<Date>) {
            self.date = date
        }

        @objc func dateChanged(_ sender: NSDatePicker) {
            date.wrappedValue = sender.dateValue
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(date: $date)
    }

    func makeNSView(context: Context) -> NSDatePicker {
        let picker = NSDatePicker()
        picker.datePickerStyle = .textField
        picker.datePickerElements = [.yearMonthDay, .hourMinute]
        picker.locale = Locale(identifier: "es")
        picker.isBezeled = false
        picker.isBordered = false
        picker.drawsBackground = false
        picker.font = Theme.Font.field
        picker.textColor = NSColor(Theme.NewPriority.dateText)
        picker.dateValue = date
        picker.target = context.coordinator
        picker.action = #selector(Coordinator.dateChanged(_:))
        picker.setAccessibilityLabel("Fecha límite")
        return picker
    }

    func updateNSView(_ picker: NSDatePicker, context: Context) {
        context.coordinator.date = $date
        if picker.dateValue != date {
            picker.dateValue = date
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSDatePicker, context: Context) -> CGSize? {
        nsView.fittingSize
    }
}

struct DueDateField: View {
    @Binding var dueAt: Date?
    let now: Date

    var body: some View {
        if dueAt == nil {
            Button {
                dueAt = NewPriorityDraft.defaultDue(after: now)
            } label: {
                HStack {
                    Text("Sin fecha")
                        .font(Theme.Font.label)
                        .foregroundStyle(Theme.Text.dim)
                    Spacer(minLength: 0)
                    IconView(icon: .calendar, size: Theme.NewPriority.dateIconSize)
                        .foregroundStyle(Theme.Text.muted)
                }
                .padding(.horizontal, Theme.NewPriority.datePadding)
                .modifier(FormInputChrome(height: Theme.NewPriority.dateHeight, radius: Theme.NewPriority.dateRadius))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 4) {
                DateFieldPicker(
                    date: Binding(
                        get: { dueAt ?? now },
                        set: { dueAt = $0 }
                    )
                )
                .padding(.leading, -Theme.NewPriority.datePickerInset)
                Spacer(minLength: 0)
                Button {
                    dueAt = nil
                } label: {
                    IconView(icon: .close, size: Theme.NewPriority.dateClearIconSize)
                        .foregroundStyle(Theme.Text.muted)
                        .frame(width: Theme.NewPriority.dateClearSize, height: Theme.NewPriority.dateClearSize)
                }
                .buttonStyle(.ghost)
                .accessibilityLabel("Quitar fecha")
            }
            .padding(.horizontal, Theme.NewPriority.datePadding)
            .modifier(FormInputChrome(height: Theme.NewPriority.dateHeight, radius: Theme.NewPriority.dateRadius))
        }
    }
}

struct NewPriorityFormView: View {
    @Binding var form: NewPriorityForm
    let now: Date
    var alertsOff = false
    var showsTitleFocus = false
    var limitNotice: String?
    let onSubmit: () -> Void

    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(spacing: Theme.NewPriority.cardSpacing) {
            titleField
            labeledRow("Prioridad") {
                LevelSegmentedPicker(selection: $form.draft.level)
            }
            labeledRow("Fecha límite") {
                DueDateField(dueAt: $form.draft.dueAt, now: now)
            }
            if form.draft.showsAlertHint {
                HStack(spacing: Theme.NewPriority.hintSpacing) {
                    IconView(icon: alertsOff ? .bellSlash : .bell, size: Theme.NewPriority.hintIconSize)
                    if alertsOff {
                        AlertsOffNotice()
                    } else {
                        Text("Alerta con sonido 30 min antes y al vencer")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .font(Theme.Font.meta)
                .foregroundStyle(Theme.Text.muted)
            }
            if let limitNotice {
                LimitNotice(text: limitNotice)
            }
            HStack(spacing: Theme.NewPriority.buttonsSpacing) {
                Spacer(minLength: 0)
                FormActionButton(title: "Cancelar", padding: Theme.NewPriority.cancelPadding) {
                    form.cancel()
                }
                FormActionButton(title: "Añadir", padding: Theme.NewPriority.addPadding, isPrimary: true, action: onSubmit)
            }
            .padding(.bottom, Theme.Key.sideHeight)
        }
        .padding(Theme.NewPriority.cardPadding)
        .background(
            Theme.NewPriority.cardBackground,
            in: RoundedRectangle(cornerRadius: Theme.NewPriority.cardRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.NewPriority.cardRadius, style: .continuous)
                .strokeBorder(Theme.NewPriority.cardBorder, lineWidth: 1)
        )
        .onKeyPress(.escape) {
            form.close()
            return .handled
        }
        .onAppear { titleFocused = true }
    }

    private var titleField: some View {
        TextField("", text: $form.draft.title)
            .textFieldStyle(.plain)
            .font(Theme.Font.body)
            .foregroundStyle(Theme.Text.primary)
            .tint(Theme.Accent.caret)
            .focused($titleFocused)
            .onSubmit(onSubmit)
            .onExitCommand { form.close() }
            .overlay(alignment: .leading) {
                if form.draft.title.isEmpty {
                    Text("¿Qué es prioritario?")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Text.dim)
                        .allowsHitTesting(false)
                }
            }
        .padding(.horizontal, Theme.NewPriority.titlePadding)
        .modifier(FormInputChrome(
            height: Theme.NewPriority.titleHeight,
            radius: Theme.NewPriority.titleRadius,
            isFocused: titleFocused || showsTitleFocus
        ))
        .accessibilityLabel("Prioridad")
    }

    private func labeledRow(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: Theme.NewPriority.cardSpacing) {
            Text(label)
                .font(Theme.Font.meta)
                .foregroundStyle(Theme.Text.muted)
                .lineLimit(1)
                .frame(width: Theme.NewPriority.labelWidth, alignment: .leading)
            content()
                .frame(maxWidth: .infinity)
        }
    }
}
