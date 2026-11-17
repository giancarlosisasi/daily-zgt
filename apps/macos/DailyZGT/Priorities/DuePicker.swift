import AppKit
import SwiftUI

enum DueQuickOption: CaseIterable, Sendable {
    case today
    case tomorrow
    case nextMonday
    case inOneWeek

    var title: String {
        switch self {
        case .today: "Hoy"
        case .tomorrow: "Mañana"
        case .nextMonday: "Próximo lunes"
        case .inOneWeek: "En una semana"
        }
    }

    func date(current: Date?, now: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        let day: Date
        switch self {
        case .today:
            day = today
        case .tomorrow:
            day = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        case .nextMonday:
            let weekday = calendar.component(.weekday, from: today)
            let ahead = (9 - weekday) % 7
            day = calendar.date(byAdding: .day, value: ahead == 0 ? 7 : ahead, to: today) ?? today
        case .inOneWeek:
            day = calendar.date(byAdding: .day, value: 7, to: today) ?? today
        }
        return DueParts.join(day: day, time: current ?? NewPriorityDraft.defaultDue(after: now), calendar: calendar)
    }
}

enum DueParts {
    static func join(day: Date, time: Date, calendar: Calendar = .current) -> Date {
        let dayParts = calendar.dateComponents([.year, .month, .day], from: day)
        let timeParts = calendar.dateComponents([.hour, .minute], from: time)
        var parts = DateComponents()
        parts.year = dayParts.year
        parts.month = dayParts.month
        parts.day = dayParts.day
        parts.hour = timeParts.hour
        parts.minute = timeParts.minute
        return calendar.date(from: parts) ?? day
    }
}

final class CommitDatePicker: NSDatePicker {
    var onCommit: () -> Void = {}

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 {
            onCommit()
            return
        }
        super.keyDown(with: event)
    }
}

struct NativeDatePicker: NSViewRepresentable {
    enum Kind {
        case calendar
        case dayField
        case timeField
    }

    let kind: Kind
    @Binding var date: Date
    var onCommit: () -> Void = {}

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

    func makeNSView(context: Context) -> CommitDatePicker {
        let picker = CommitDatePicker()
        picker.locale = Locale(identifier: "es")
        picker.font = Theme.DatePopover.fieldFont
        picker.textColor = NSColor(Theme.DatePopover.fieldText)
        switch kind {
        case .calendar:
            picker.datePickerStyle = .clockAndCalendar
            picker.datePickerElements = .yearMonthDay
            picker.drawsBackground = false
            picker.isBezeled = false
            picker.setAccessibilityLabel("Calendario")
        case .dayField:
            picker.datePickerStyle = .textFieldAndStepper
            picker.datePickerElements = .yearMonthDay
            picker.isBezeled = false
            picker.isBordered = false
            picker.drawsBackground = false
            picker.setAccessibilityLabel("Fecha")
        case .timeField:
            picker.datePickerStyle = .textFieldAndStepper
            picker.datePickerElements = .hourMinute
            picker.isBezeled = false
            picker.isBordered = false
            picker.drawsBackground = false
            picker.setAccessibilityLabel("Hora")
        }
        picker.dateValue = date
        picker.onCommit = onCommit
        picker.target = context.coordinator
        picker.action = #selector(Coordinator.dateChanged(_:))
        return picker
    }

    func updateNSView(_ picker: CommitDatePicker, context: Context) {
        context.coordinator.date = $date
        picker.onCommit = onCommit
        if picker.dateValue != date {
            picker.dateValue = date
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: CommitDatePicker, context: Context) -> CGSize? {
        nsView.fittingSize
    }
}

struct DuePopoverContent: View {
    @Binding var dueAt: Date?
    let now: Date
    var alertsOff = false
    var onClose: () -> Void = {}

    private var current: Date { dueAt ?? NewPriorityDraft.defaultDue(after: now) }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.DatePopover.columnSpacing) {
            options
            VStack(alignment: .leading, spacing: Theme.DatePopover.rowSpacing) {
                field {
                    NativeDatePicker(kind: .dayField, date: dayBinding, onCommit: onClose)
                }
                NativeDatePicker(kind: .calendar, date: dayBinding, onCommit: onClose)
                HStack(spacing: Theme.DatePopover.iconSpacing) {
                    Text("Hora")
                        .font(Theme.DatePopover.labelFont)
                        .foregroundStyle(Theme.DatePopover.labelText)
                    field {
                        NativeDatePicker(kind: .timeField, date: timeBinding, onCommit: onClose)
                    }
                }
                HStack(spacing: Theme.DatePopover.iconSpacing) {
                    IconView(icon: alertsOff ? .bellSlash : .bell, size: Theme.DatePopover.iconSize)
                    Text(PriorityDetailLabels.alert(due: current))
                }
                .font(Theme.DatePopover.alertFont)
                .foregroundStyle(Theme.DatePopover.alertText)
            }
            .fixedSize()
        }
        .padding(Theme.DatePopover.padding)
        .background(Theme.DatePopover.background)
        .environment(\.colorScheme, .dark)
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(DueQuickOption.allCases, id: \.self) { option in
                optionButton(option.title, color: Theme.DatePopover.optionText) {
                    dueAt = option.date(current: dueAt, now: now)
                    onClose()
                }
            }
            Spacer(minLength: Theme.DatePopover.rowSpacing)
            optionButton("Quitar fecha", color: Theme.DatePopover.clearText) {
                dueAt = nil
                onClose()
            }
        }
        .frame(width: Theme.DatePopover.optionWidth)
    }

    private func optionButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.DatePopover.optionFont)
                .foregroundStyle(color)
                .padding(.horizontal, Theme.DatePopover.optionPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: Theme.DatePopover.optionHeight)
        }
        .buttonStyle(.ghost)
    }

    private func field(@ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(.horizontal, Theme.DatePopover.fieldPadding)
            .frame(height: Theme.DatePopover.fieldHeight)
            .background(
                Theme.DatePopover.fieldBackground,
                in: RoundedRectangle(cornerRadius: Theme.DatePopover.fieldRadius, style: .continuous)
            )
    }

    private var dayBinding: Binding<Date> {
        Binding(
            get: { current },
            set: { dueAt = DueParts.join(day: $0, time: current) }
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { current },
            set: { dueAt = DueParts.join(day: current, time: $0) }
        )
    }
}

struct DueDateField: View {
    @Binding var dueAt: Date?
    let now: Date
    var alertsOff = false

    @State private var isOpen = false

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            HStack(spacing: Theme.Detail.valueSpacing) {
                IconView(icon: .calendar, size: Theme.Detail.valueIconSize)
                Text(PriorityDetailLabels.due(dueAt, now: now))
                    .lineLimit(1)
            }
            .font(Theme.Detail.valueFont)
            .foregroundStyle(color)
            .padding(.horizontal, Theme.Detail.valuePadding)
            .frame(height: Theme.Detail.valueHeight)
        }
        .buttonStyle(.ghost)
        .fixedSize()
        .accessibilityLabel("Fecha límite")
        .accessibilityValue(PriorityDetailLabels.due(dueAt, now: now))
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            DuePopoverContent(dueAt: $dueAt, now: now, alertsOff: alertsOff, onClose: { isOpen = false })
        }
    }

    private var color: Color {
        guard let dueAt else { return Theme.Detail.valueDim }
        return dueAt < now ? Theme.Detail.valueLate : Theme.Detail.valueText
    }
}

struct CalendarRangePicker: NSViewRepresentable {
    let start: Date
    var interval: TimeInterval = 0
    let onChange: (Date, TimeInterval) -> Void

    @MainActor
    final class Coordinator: NSObject {
        var onChange: (Date, TimeInterval) -> Void

        init(onChange: @escaping (Date, TimeInterval) -> Void) {
            self.onChange = onChange
        }

        @objc func dateChanged(_ sender: NSDatePicker) {
            onChange(sender.dateValue, sender.timeInterval)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeNSView(context: Context) -> NSDatePicker {
        let picker = NSDatePicker()
        picker.locale = Locale(identifier: "es")
        picker.font = Theme.DatePopover.fieldFont
        picker.textColor = NSColor(Theme.DatePopover.fieldText)
        picker.datePickerStyle = .clockAndCalendar
        picker.datePickerElements = .yearMonthDay
        picker.datePickerMode = .range
        picker.drawsBackground = false
        picker.isBezeled = false
        picker.setAccessibilityLabel(DueFilterLabels.pickRange)
        picker.dateValue = start
        picker.timeInterval = interval
        picker.target = context.coordinator
        picker.action = #selector(Coordinator.dateChanged(_:))
        return picker
    }

    func updateNSView(_ picker: NSDatePicker, context: Context) {
        context.coordinator.onChange = onChange
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSDatePicker, context: Context) -> CGSize? {
        nsView.fittingSize
    }
}
