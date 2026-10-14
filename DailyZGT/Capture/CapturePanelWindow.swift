import AppKit
import SwiftUI

final class CaptureNSPanel: NSPanel {
    var onCancel: (@MainActor () -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

@MainActor
final class CapturePanelWindow: CaptureWindow {
    let panel: CaptureNSPanel

    private weak var controller: CaptureController?
    private let reveal = CaptureReveal()
    private let mouse: @MainActor () -> CGPoint
    private let screens: @MainActor () -> [ScreenGeometry]
    private var observers: [any NSObjectProtocol] = []
    private var mouseMonitor: Any?
    private var hideTask: Task<Void, Never>?
    private var frontApp: NSRunningApplication?
    private var restoresFrontApp = true

    init(
        controller: CaptureController,
        mouse: @escaping @MainActor () -> CGPoint = { NSEvent.mouseLocation },
        screens: @escaping @MainActor () -> [ScreenGeometry] = { CapturePlacement.currentScreens() }
    ) {
        self.controller = controller
        self.mouse = mouse
        self.screens = screens
        panel = CaptureNSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.onCancel = { [weak controller] in controller?.cancel() }
    }

    func show() {
        guard let controller else { return }
        hideTask?.cancel()
        hideTask = nil
        reveal.isRevealed = false
        let hosting = NSHostingView(rootView: CaptureView(
            model: controller.model,
            reveal: reveal,
            onSubmit: { [weak controller] in controller?.submit() },
            onCancel: { [weak controller] in controller?.cancel() },
            onSize: { [weak self] size in self?.resize(to: size) }
        ))
        hosting.sizingOptions = [.intrinsicContentSize]
        panel.contentView = hosting
        let frame = CapturePlacement.frame(size: hosting.fittingSize, mouse: mouse(), screens: screens())
        panel.setFrame(frame, display: false)
        observe()
        rememberFrontApp()
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        stopObserving()
        restoreFrontApp()
        let policy = MotionPolicy(reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        policy.perform(.pop) { reveal.isRevealed = false }
        guard policy.animates else {
            panel.orderOut(nil)
            return
        }
        hideTask = Task { [weak self, delay = policy.popDuration] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.panel.orderOut(nil)
        }
    }

    private func rememberFrontApp() {
        let front = NSWorkspace.shared.frontmostApplication
        frontApp = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : front
        restoresFrontApp = true
    }

    private func restoreFrontApp() {
        if restoresFrontApp {
            frontApp?.activate()
        }
        frontApp = nil
    }

    private func dismissByFocusLoss() {
        restoresFrontApp = false
        controller?.close()
    }

    private func resize(to size: CGSize) {
        guard size.width > 0, size.height > 0, panel.isVisible else { return }
        let current = panel.frame
        guard abs(current.height - size.height) > 0.5 || abs(current.width - size.width) > 0.5 else { return }
        panel.setFrame(
            CGRect(x: current.minX, y: current.maxY - size.height, width: size.width, height: size.height),
            display: true
        )
    }

    private func observe() {
        stopObserving()
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: panel, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.controller?.model.requestFocus() }
            },
            center.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.dismissByFocusLoss() }
            },
        ]
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismissByFocusLoss() }
        }
    }

    private func stopObserving() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
        mouseMonitor = nil
    }
}
