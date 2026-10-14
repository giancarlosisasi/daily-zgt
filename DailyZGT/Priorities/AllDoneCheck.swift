import SwiftUI

struct CheckMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 7 * scale, y: rect.minY + 12.5 * scale))
        path.addLine(to: CGPoint(x: rect.minX + 10.2 * scale, y: rect.minY + 15.7 * scale))
        path.addLine(to: CGPoint(x: rect.minX + 17 * scale, y: rect.minY + 9 * scale))
        return path
    }
}

struct AllDoneMark: View {
    var progress = 1.0

    var body: some View {
        let scale = Theme.AllDone.size / 24
        ZStack {
            Circle()
                .stroke(Theme.AllDone.color.opacity(Theme.AllDone.circleOpacity), lineWidth: Theme.AllDone.lineWidth)
                .frame(width: 20 * scale, height: 20 * scale)
            CheckMarkShape()
                .trim(from: 0, to: progress)
                .stroke(
                    Theme.AllDone.color,
                    style: StrokeStyle(lineWidth: Theme.AllDone.lineWidth, lineCap: .round, lineJoin: .round)
                )
                .opacity(progress > 0 ? 1 : 0)
        }
        .frame(width: Theme.AllDone.size, height: Theme.AllDone.size)
        .accessibilityHidden(true)
    }
}

struct AllDoneCheck: View {
    @Environment(\.motionPolicy) private var motion
    @State private var isDrawn = false

    var body: some View {
        AllDoneMark(progress: motion.animates && !isDrawn ? 0 : 1)
            .onAppear {
                motion.perform(.draw) { isDrawn = true }
            }
    }
}
