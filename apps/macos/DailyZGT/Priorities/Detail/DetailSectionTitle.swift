import SwiftUI

struct DetailSectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.Detail.sectionTitleFont)
            .tracking(Theme.Detail.sectionTitleTracking)
            .foregroundStyle(Theme.Text.muted)
            .accessibilityAddTraits(.isHeader)
    }
}
