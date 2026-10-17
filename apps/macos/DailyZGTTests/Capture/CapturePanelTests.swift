import AppKit
import Foundation
import Testing
@testable import DailyZGT

@Suite
struct CapturePlacementTests {
    private let size = CGSize(width: 360, height: 130)
    private let main = ScreenGeometry(
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 950)
    )
    private let right = ScreenGeometry(
        frame: CGRect(x: 1512, y: -200, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 1512, y: -200, width: 1920, height: 1055)
    )

    @Test
    func theWindowIsCenteredAtTheTopOfTheScreenWithTheMouse() {
        let frame = CapturePlacement.frame(size: size, mouse: CGPoint(x: 200, y: 300), screens: [main, right])
        #expect(frame.midX == main.visibleFrame.midX)
        #expect(frame.maxY == main.visibleFrame.maxY - Theme.Capture.topInset)
        #expect(frame.size == size)
    }

    @Test
    func theWindowFollowsTheMouseToAnotherScreen() {
        let frame = CapturePlacement.frame(size: size, mouse: CGPoint(x: 2000, y: 100), screens: [main, right])
        #expect(frame.midX == right.visibleFrame.midX)
        #expect(frame.maxY == right.visibleFrame.maxY - Theme.Capture.topInset)
        #expect(right.frame.contains(CGPoint(x: frame.midX, y: frame.midY)))
    }

    @Test
    func aMouseOutsideEveryScreenFallsBackToTheFirstScreen() {
        let frame = CapturePlacement.frame(size: size, mouse: CGPoint(x: -5000, y: -5000), screens: [main, right])
        #expect(frame.midX == main.visibleFrame.midX)
    }

    @Test
    func noScreenGivesAFrameAtTheOrigin() {
        #expect(CapturePlacement.frame(size: size, mouse: .zero, screens: []) == CGRect(origin: .zero, size: size))
    }

    @Test
    func aWindowTallerThanTheScreenStaysInsideTheVisibleArea() {
        let tall = CGSize(width: 360, height: 5000)
        let frame = CapturePlacement.frame(size: tall, mouse: CGPoint(x: 200, y: 300), screens: [main])
        #expect(frame.minY >= main.visibleFrame.minY)
    }

    @Test
    func aWindowWiderThanTheScreenStartsAtItsLeftEdge() {
        let wide = CGSize(width: 4000, height: 130)
        let frame = CapturePlacement.frame(size: wide, mouse: CGPoint(x: 200, y: 300), screens: [main])
        #expect(frame.minX == main.visibleFrame.minX)
    }
}

@Suite
struct CaptureMotionTests {
    @Test
    func theWindowClosesAtOnceWithReduceMotion() {
        #expect(MotionPolicy(reduceMotion: true).popDuration == .zero)
        #expect(MotionPolicy(reduceMotion: true).animation(.pop) == nil)
    }

    @Test
    func theWindowOpensAndClosesWithThePanelOpenDuration() {
        #expect(MotionPolicy(reduceMotion: false).popDuration == Duration.tecla(Theme.Motion.panelOpen))
        #expect(MotionPolicy(reduceMotion: false).animation(.pop) != nil)
    }

    @Test
    func theWindowStartsHiddenAndEndsFullSize() {
        let hidden = PopFrame(revealed: false)
        let shown = PopFrame(revealed: true)
        #expect(hidden.opacity == 0)
        #expect(shown.opacity == 1)
        #expect(hidden.scale < shown.scale)
        #expect(shown.scale == 1)
    }
}

@Suite
@MainActor
struct CapturePanelWindowTests {
    private func makePanel() throws -> (CapturePanelWindow, CaptureController) {
        let controller = CaptureController(store: try makeStore(), makeWindow: { _ in FakeCaptureWindow() })
        return (CapturePanelWindow(controller: controller), controller)
    }

    @Test
    func thePanelCanBecomeKeyButNotMain() throws {
        let (window, _) = try makePanel()
        #expect(window.panel.canBecomeKey)
        #expect(!window.panel.canBecomeMain)
    }

    @Test
    func thePanelDoesNotActivateTheApp() throws {
        let (window, _) = try makePanel()
        #expect(window.panel.styleMask.contains(.nonactivatingPanel))
        #expect(window.panel.styleMask.contains(.borderless))
        #expect(!window.panel.hidesOnDeactivate)
    }

    @Test
    func thePanelFloatsAboveOtherWindows() throws {
        let (window, _) = try makePanel()
        #expect(window.panel.level == .floating)
        #expect(window.panel.isFloatingPanel)
    }

    @Test
    func thePanelShowsOnTheActiveSpaceAndOverFullScreenApps() throws {
        let (window, _) = try makePanel()
        #expect(window.panel.collectionBehavior.contains(.moveToActiveSpace))
        #expect(window.panel.collectionBehavior.contains(.fullScreenAuxiliary))
        #expect(!window.panel.collectionBehavior.contains(.canJoinAllSpaces))
    }

    @Test
    func thePanelHasNoBackgroundOfItsOwn() throws {
        let (window, _) = try makePanel()
        #expect(!window.panel.isOpaque)
        #expect(window.panel.backgroundColor == .clear)
        #expect(window.panel.hasShadow)
    }

    @Test
    func aNewPanelIsNotVisible() throws {
        let (window, _) = try makePanel()
        #expect(!window.panel.isVisible)
    }

    @Test
    func theEscapeKeyOfThePanelCancelsTheCapture() throws {
        let (window, controller) = try makePanel()
        controller.open()
        #expect(controller.isOpen)
        window.panel.cancelOperation(nil)
        #expect(!controller.isOpen)
    }
}
