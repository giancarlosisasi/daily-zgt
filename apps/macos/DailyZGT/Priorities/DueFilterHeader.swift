import SwiftUI

struct DueFilterHeader: View {
    @Environment(AppStore.self) private var store
    @Environment(PanelState.self) private var state

    var body: some View {
        TimelineView(.everyMinute) { _ in
            content(store.dueDays)
        }
    }

    private func content(_ days: DueDays) -> some View {
        let filter = state.filter
        return FilterHeader(
            title: DueFilterLabels.title(filter, days),
            subtitle: DueFilterLabels.subtitle(filter, days, openCount: store.openCount(in: filter, days: days)),
            showsSteps: filter.isSingleDay,
            onStep: { state.step(by: $0) }
        ) { close in
            DueFilterPopover(
                selection: filter,
                days: days,
                counts: Dictionary(uniqueKeysWithValues: DueFilter.quickOptions.map { ($0, store.openCount(in: $0, days: days)) }),
                onSelect: { state.select(filter: $0) },
                onClose: close
            )
        }
    }
}

struct FilterHeader<Popover: View>: View {
    let title: String
    let subtitle: String?
    let showsSteps: Bool
    var canStepForward = true
    let onStep: (Int) -> Void
    @ViewBuilder let popover: (_ close: @escaping () -> Void) -> Popover

    @Environment(\.panelLayout) private var layout
    @State private var isOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Filter.titleSpacing) {
            HStack(alignment: .center, spacing: Theme.Space.s2) {
                Text(title)
                    .font(layout == .window ? Theme.Filter.windowTitleFont : Theme.Filter.panelTitleFont)
                    .foregroundStyle(Theme.Filter.titleText)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                filterKey
            }
            if subtitle != nil || showsSteps {
                HStack(spacing: Theme.Filter.subtitleSpacing) {
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.Filter.subtitleFont)
                            .foregroundStyle(Theme.Filter.subtitleText)
                            .lineLimit(1)
                    }
                    if showsSteps {
                        stepButton(.caretLeft, label: DueFilterLabels.previousDay) { onStep(-1) }
                        stepButton(.caretRight, label: DueFilterLabels.nextDay) { onStep(1) }
                            .disabled(!canStepForward)
                            .opacity(canStepForward ? 1 : 0)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stepButton(_ icon: Icon, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            IconView(icon: icon, size: Theme.Filter.stepIconSize)
                .foregroundStyle(Theme.Filter.stepText)
                .frame(width: Theme.Filter.stepSize, height: Theme.Filter.stepSize)
        }
        .buttonStyle(.ghost)
        .accessibilityLabel(label)
        .help(label)
    }

    private var filterKey: some View {
        Button {
            isOpen.toggle()
        } label: {
            HStack(spacing: Theme.Filter.keySpacing) {
                IconView(icon: .calendar, size: Theme.Filter.keyIconSize)
                IconView(icon: .caretRight, size: Theme.Filter.keyCaretSize)
                    .rotationEffect(.degrees(Theme.MotionShape.caretOpenDegrees))
            }
            .padding(.horizontal, Theme.Filter.keyPadding)
            .frame(height: Theme.Filter.keyHeight)
        }
        .buttonStyle(KeyButtonStyle(role: .graphite, radius: Theme.Filter.keyRadius))
        .fixedSize()
        .padding(.bottom, Theme.Key.sideHeight)
        .accessibilityLabel(DueFilterLabels.filterKey)
        .help(DueFilterLabels.filterKey)
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            popover { isOpen = false }
        }
    }
}

enum DuePickMode: Hashable {
    case day
    case range
}

struct DueFilterPopover: View {
    let selection: DueFilter
    let days: DueDays
    let counts: [DueFilter: Int]
    var options = DueFilter.quickOptions
    var optionTitle: (DueFilter) -> String = DueFilterLabels.option
    let onSelect: (DueFilter) -> Void
    var onClose: () -> Void = {}

    @State private var mode: DuePickMode
    @State private var rangePick = RangePick()
    @State private var shownDay: Date

    init(
        selection: DueFilter,
        days: DueDays,
        counts: [DueFilter: Int],
        options: [DueFilter] = DueFilter.quickOptions,
        optionTitle: @escaping (DueFilter) -> String = DueFilterLabels.option,
        mode: DuePickMode? = nil,
        onSelect: @escaping (DueFilter) -> Void,
        onClose: @escaping () -> Void = {}
    ) {
        self.selection = selection
        self.days = days
        self.counts = counts
        self.options = options
        self.optionTitle = optionTitle
        self.onSelect = onSelect
        self.onClose = onClose
        let isRange = if case .range = selection.resolved(days) { true } else { false }
        _mode = State(initialValue: mode ?? (isRange ? .range : .day))
        _shownDay = State(initialValue: selection.span(days)?.lowerBound ?? days.today)
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Filter.popoverColumnSpacing) {
            optionList
            VStack(alignment: .leading, spacing: Theme.Filter.popoverRowSpacing) {
                SegmentedTabs(
                    style: .scope,
                    options: [
                        .init(value: DuePickMode.day, title: DueFilterLabels.pickDay),
                        .init(value: DuePickMode.range, title: DueFilterLabels.pickRange),
                    ],
                    selection: $mode
                )
                switch mode {
                case .day:
                    NativeDatePicker(kind: .calendar, date: Binding(get: { shownDay }, set: { pickDay($0) }))
                case .range:
                    CalendarRangePicker(start: shownDay, interval: shownInterval, onChange: { pickRange($0, $1) })
                    Text(rangePick.first == nil ? DueFilterLabels.rangeFirstHint : DueFilterLabels.rangeLastHint)
                        .font(Theme.Filter.hintFont)
                        .foregroundStyle(Theme.Filter.hintText)
                }
            }
            .fixedSize()
        }
        .padding(Theme.Filter.popoverPadding)
        .background(Theme.Filter.background)
        .environment(\.colorScheme, .dark)
    }

    private var shownInterval: TimeInterval {
        guard case let .range(_, last) = selection.resolved(days), let end = days.start(of: last) else { return 0 }
        return max(end.timeIntervalSince(shownDay), 0)
    }

    private var optionList: some View {
        let current = selection.resolved(days)
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button {
                    onSelect(option)
                    onClose()
                } label: {
                    HStack(spacing: Theme.Space.s2) {
                        Text(optionTitle(option))
                        Spacer(minLength: 0)
                        if option != .all, let count = counts[option] {
                            Text("\(count)")
                                .font(Theme.Filter.optionCountFont)
                                .foregroundStyle(Theme.Filter.optionCountText)
                        }
                    }
                    .font(Theme.Filter.optionFont)
                    .foregroundStyle(Theme.Filter.optionText)
                    .padding(.horizontal, Theme.Filter.optionPadding)
                    .frame(height: Theme.Filter.optionHeight)
                    .background(
                        option == current ? Theme.Filter.optionSelected : Color.clear,
                        in: RoundedRectangle(cornerRadius: Theme.Filter.optionRadius, style: .continuous)
                    )
                }
                .buttonStyle(.ghost)
                .accessibilityAddTraits(option == current ? .isSelected : [])
            }
        }
        .frame(width: Theme.Filter.optionWidth)
    }

    private func pickDay(_ day: Date) {
        let isMonthStep = CalendarClick.isMonthStep(from: shownDay, to: day, calendar: days.calendar)
        shownDay = day
        guard !isMonthStep else { return }
        onSelect(DueFilter.picked(day: day, days))
        onClose()
    }

    private func pickRange(_ day: Date, _ interval: TimeInterval) {
        let last = day.addingTimeInterval(interval)
        if days.dayCount(from: day, to: last) >= 1 {
            rangePick.reset()
            shownDay = day
            onSelect(DueFilter.picked(from: day, to: last, days))
            return
        }
        let isMonthStep = CalendarClick.isMonthStep(from: shownDay, to: day, calendar: days.calendar)
        shownDay = day
        guard !isMonthStep else { return }
        if let (first, last) = rangePick.pick(day) {
            onSelect(DueFilter.picked(from: first, to: last, days))
            onClose()
        }
    }
}

struct OverdueLink: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(DueFilterLabels.overdueLink(count)) · \(DueFilterLabels.showOverdue)")
                .font(Theme.Filter.linkFont)
                .foregroundStyle(Theme.Filter.linkText)
                .padding(.horizontal, Theme.Filter.linkPadding)
                .frame(height: Theme.Filter.linkHeight)
        }
        .buttonStyle(.ghost)
        .linkCursor()
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, Theme.Filter.linkBottomPadding)
    }
}
