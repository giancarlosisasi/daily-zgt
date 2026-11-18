import SwiftUI

struct DoneConfirmationBar: View {
    var title = "¿Marcar como hecha?"
    let openSubtasksLabel: String?
    var usesRowMargins = true
    var confirmIcon = Icon.check
    var confirmTitle = "Hecha"
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        HStack(spacing: Theme.Confirm.spacing) {
            VStack(alignment: .leading, spacing: Theme.Confirm.textSpacing) {
                Text(title)
                    .font(Theme.Confirm.titleFont)
                    .foregroundStyle(Theme.Confirm.title)
                    .fixedSize(horizontal: false, vertical: true)
                if let openSubtasksLabel {
                    Text(openSubtasksLabel)
                        .font(Theme.Confirm.hintFont)
                        .foregroundStyle(Theme.Confirm.hint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onCancel) {
                Text("Cancelar")
                    .font(Theme.Confirm.buttonFont)
                    .padding(.horizontal, Theme.Confirm.buttonPadding)
                    .frame(height: Theme.Confirm.buttonHeight)
            }
            .buttonStyle(KeyButtonStyle(role: .graphite, radius: Theme.Confirm.buttonRadius))
            .fixedSize()
            Button(action: onConfirm) {
                HStack(spacing: Theme.Confirm.checkSpacing) {
                    IconView(icon: confirmIcon, size: Theme.Confirm.checkSize)
                    Text(confirmTitle)
                        .font(Theme.Confirm.doneFont)
                }
                .padding(.horizontal, Theme.Confirm.buttonPadding)
                .frame(height: Theme.Confirm.buttonHeight)
            }
            .buttonStyle(KeyButtonStyle(role: .primary, radius: Theme.Confirm.buttonRadius))
            .fixedSize()
        }
        .padding(.vertical, Theme.Confirm.verticalPadding)
        .padding(.leading, Theme.Confirm.leadingPadding)
        .padding(.trailing, Theme.Confirm.trailingPadding)
        .background(Theme.Confirm.background, in: RoundedRectangle(cornerRadius: Theme.Confirm.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Confirm.radius, style: .continuous)
                .strokeBorder(Theme.Confirm.border, lineWidth: 1)
        )
        .padding(.top, usesRowMargins ? Theme.Confirm.topMargin : 0)
        .padding(.leading, usesRowMargins ? Theme.Confirm.leadingMargin : 0)
        .padding(.trailing, usesRowMargins ? Theme.Confirm.trailingMargin : 0)
        .padding(.bottom, usesRowMargins ? Theme.Confirm.bottomMargin : 0)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Confirmar")
    }
}

extension TimedUndo {
    func lineFraction(at now: Date, reduceMotion: Bool) -> Double {
        reduceMotion ? 1 : remainingFraction(at: now)
    }
}

struct UndoBar: View {
    let title: String
    var remaining: Double = 1
    var prefix = "Hecha"
    var icon = Icon.check
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: Theme.Undo.spacing) {
            IconView(icon: icon, size: Theme.Undo.checkSize)
                .foregroundStyle(Theme.Undo.check)
            Text("\(prefix): \(title)")
                .font(Theme.Undo.font)
                .foregroundStyle(Theme.Undo.text)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onUndo) {
                Text("Deshacer")
                    .font(Theme.Undo.buttonFont)
                    .foregroundStyle(Theme.Undo.button)
                    .padding(.horizontal, Theme.Undo.buttonPadding)
                    .frame(height: Theme.Undo.buttonHeight)
            }
            .buttonStyle(GhostButtonStyle(radius: Theme.Undo.buttonRadius))
        }
        .padding(.vertical, Theme.Undo.verticalPadding)
        .padding(.leading, Theme.Undo.leadingPadding)
        .padding(.trailing, Theme.Undo.trailingPadding)
        .background(Theme.Undo.background)
        .overlay(alignment: .bottomLeading) {
            Rectangle()
                .fill(Theme.Undo.line)
                .frame(height: Theme.Undo.lineHeight)
                .scaleEffect(x: remaining, y: 1, anchor: .leading)
                .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Undo.radius, style: .continuous))
    }
}

struct TimedUndoBar<Undo: TimedUndo>: View {
    let undo: Undo
    var prefix = "Hecha"
    var icon = Icon.check
    let onUndo: () -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.motionPolicy) private var motion

    var body: some View {
        TimelineView(.animation(paused: !motion.animates)) { _ in
            UndoBar(
                title: undo.title,
                remaining: undo.lineFraction(at: store.now(), reduceMotion: motion.reduceMotion),
                prefix: prefix,
                icon: icon,
                onUndo: onUndo
            )
        }
    }
}
