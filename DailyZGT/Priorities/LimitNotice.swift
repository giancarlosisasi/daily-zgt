import SwiftUI

struct LimitNotice: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.Limit.noticeFont)
            .foregroundStyle(Theme.Limit.noticeText)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
