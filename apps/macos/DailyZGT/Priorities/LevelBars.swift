import SwiftUI

extension PriorityLevel {
    var barCount: Int {
        switch self {
        case .high: 3
        case .medium: 2
        case .low: 1
        }
    }

    var color: Color {
        switch self {
        case .high: Theme.Level.high
        case .medium: Theme.Level.medium
        case .low: Theme.Level.low
        }
    }

    var label: String {
        switch self {
        case .high: "Alta"
        case .medium: "Media"
        case .low: "Baja"
        }
    }
}

struct LevelBars: View {
    let level: PriorityLevel

    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Level.barSpacing) {
            ForEach(Array(Theme.Level.barHeights.enumerated()), id: \.offset) { index, height in
                RoundedRectangle(cornerRadius: Theme.Level.barRadius, style: .continuous)
                    .fill(index < level.barCount ? level.color : Theme.Level.unfilled)
                    .frame(width: Theme.Level.barWidth, height: height)
            }
        }
        .frame(height: Theme.Level.boxHeight, alignment: .bottom)
        .accessibilityElement()
        .accessibilityLabel("Prioridad \(level.label.lowercased())")
    }
}
