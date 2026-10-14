import SwiftUI

enum Icon: String, CaseIterable {
    case arrowBack = "arrow-u-up-left-bold"
    case bell = "bell-bold"
    case bellSlash = "bell-slash-bold"
    case calendar = "calendar-blank-bold"
    case caretLeft = "caret-left-bold"
    case caretRight = "caret-right-bold"
    case check = "check-bold"
    case gear = "gear-bold"
    case note = "note-bold"
    case plus = "plus-bold"
    case trash = "trash-bold"
    case close = "x-bold"
}

struct IconView: View {
    let icon: Icon
    let size: CGFloat

    var body: some View {
        Image(icon.rawValue)
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
