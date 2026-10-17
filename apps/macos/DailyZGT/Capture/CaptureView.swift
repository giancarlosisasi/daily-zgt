import AppKit
import Observation
import SwiftUI

@Observable
@MainActor
final class CaptureReveal {
    var isRevealed: Bool

    init(isRevealed: Bool = false) {
        self.isRevealed = isRevealed
    }
}

struct CaptureView: View {
    @Bindable var model: CaptureModel
    var reveal: CaptureReveal
    var showsTitleFocus = false
    var onSubmit: () -> Void = {}
    var onCancel: () -> Void = {}
    var onSize: (CGSize) -> Void = { _ in }

    @FocusState private var titleFocused: Bool
    @Environment(\.motionPolicy) private var motion

    var body: some View {
        let frame = PopFrame(revealed: reveal.isRevealed)
        VStack(alignment: .leading, spacing: Theme.Capture.spacing) {
            bar
            titleField
            if let notice = model.notice {
                LimitNotice(text: notice)
            }
            Text(CaptureCopy.hint)
                .font(Theme.Capture.hintFont)
                .foregroundStyle(Theme.Capture.hintText)
        }
        .panelChrome(padding: Theme.Capture.padding)
        .onGeometryChange(for: CGSize.self, of: { $0.size }, action: { onSize($0) })
        .opacity(frame.opacity)
        .scaleEffect(frame.scale, anchor: .top)
        .offset(y: frame.offsetY)
        .onAppear {
            titleFocused = true
            motion.perform(.pop) { reveal.isRevealed = true }
        }
        .onChange(of: model.focusRequests) { titleFocused = true }
    }

    private var bar: some View {
        HStack(spacing: Theme.Capture.barSpacing) {
            Image(nsImage: MenuBarIcon.makeImage())
                .renderingMode(.template)
                .resizable()
                .frame(width: Theme.Capture.markSize, height: Theme.Capture.markSize)
                .foregroundStyle(Theme.Capture.markText)
            Text(CaptureCopy.title)
                .font(Theme.Capture.barFont)
                .foregroundStyle(Theme.Capture.barText)
        }
    }

    private var titleField: some View {
        TextField("", text: $model.draft.title)
            .textFieldStyle(.plain)
            .font(Theme.Capture.inputFont)
            .foregroundStyle(Theme.Text.primary)
            .tint(Theme.Accent.caret)
            .focused($titleFocused)
            .onSubmit(onSubmit)
            .onExitCommand(perform: onCancel)
            .overlay(alignment: .leading) {
                if model.draft.title.isEmpty {
                    Text(CaptureCopy.placeholder)
                        .font(Theme.Capture.inputFont)
                        .foregroundStyle(Theme.Text.dim)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, Theme.Capture.inputPadding)
            .modifier(FormInputChrome(
                height: Theme.Capture.inputHeight,
                radius: Theme.Capture.inputRadius,
                isFocused: false
            ))
            .overlay {
                if titleFocused || showsTitleFocus {
                    RoundedRectangle(cornerRadius: Theme.Capture.inputRadius, style: .continuous)
                        .strokeBorder(Theme.Capture.focusRing, lineWidth: Theme.Accent.focusRingWidth)
                }
            }
            .accessibilityLabel(CaptureCopy.title)
    }
}
