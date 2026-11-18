import SwiftUI

struct DetailSectionTitle: View {
    let text: String
    var count: String?

    var body: some View {
        HStack(spacing: Theme.Space.s2) {
            Text(text)
                .font(Theme.Detail.sectionTitleFont)
                .foregroundStyle(Theme.Detail.sectionTitleText)
                .accessibilityAddTraits(.isHeader)
            if let count {
                Text(count)
                    .font(Theme.Detail.sectionTitleFont)
                    .foregroundStyle(Theme.Detail.sectionCountText)
            }
        }
    }
}
