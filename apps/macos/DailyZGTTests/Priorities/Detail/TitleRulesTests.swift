import AppKit
import CoreGraphics
import Testing
@testable import DailyZGT

@Suite
struct TitleClickRuleTests {
    @Test
    func aClickAtTheSamePointWithNoSelectionOpens() {
        #expect(TitleClickRule.shouldOpen(down: CGPoint(x: 40, y: 20), up: CGPoint(x: 40, y: 20), selectionLength: 0))
    }

    @Test
    func aTinyMovementStillOpens() {
        #expect(TitleClickRule.shouldOpen(down: CGPoint(x: 40, y: 20), up: CGPoint(x: 42, y: 21), selectionLength: 0))
    }

    @Test
    func aDragThatSelectsTextDoesNotOpen() {
        #expect(!TitleClickRule.shouldOpen(down: CGPoint(x: 40, y: 20), up: CGPoint(x: 90, y: 20), selectionLength: 6))
    }

    @Test
    func aSelectionBlocksTheOpenEvenAtTheSamePoint() {
        #expect(!TitleClickRule.shouldOpen(down: CGPoint(x: 40, y: 20), up: CGPoint(x: 40, y: 20), selectionLength: 1))
    }

    @Test
    func aDragWithNoSelectionDoesNotOpen() {
        #expect(!TitleClickRule.shouldOpen(down: CGPoint(x: 40, y: 20), up: CGPoint(x: 90, y: 20), selectionLength: 0))
        #expect(!TitleClickRule.shouldOpen(down: CGPoint(x: 40, y: 20), up: CGPoint(x: 40, y: 30), selectionLength: 0))
    }

    @Test
    func theToleranceIsInclusive() {
        let edge = TitleClickRule.movementTolerance
        #expect(TitleClickRule.shouldOpen(down: .zero, up: CGPoint(x: edge, y: edge), selectionLength: 0))
        #expect(!TitleClickRule.shouldOpen(down: .zero, up: CGPoint(x: edge + 0.5, y: 0), selectionLength: 0))
    }
}

@Suite
struct TitleEditTests {
    @Test
    func aChangedTitleIsSavedTrimmed() {
        #expect(TitleEdit.titleToSave(draft: "  New title \n", current: "Old title") == "New title")
    }

    @Test
    func anEmptyTitleDoesNotSave() {
        #expect(TitleEdit.titleToSave(draft: "", current: "Old title") == nil)
    }

    @Test
    func aTitleOfOnlySpacesDoesNotSave() {
        #expect(TitleEdit.titleToSave(draft: " \t ", current: "Old title") == nil)
    }

    @Test
    func theSameTitleDoesNotSave() {
        #expect(TitleEdit.titleToSave(draft: "Old title", current: "Old title") == nil)
        #expect(TitleEdit.titleToSave(draft: "Old title  ", current: "Old title") == nil)
    }
}

@Suite
@MainActor
struct ClickableTitleViewTests {
    @Test
    func theAccessibilityPressOpens() {
        let view = ClickableTitleView.make()
        var opened = 0
        view.onOpen = { opened += 1 }
        #expect(view.accessibilityPerformPress())
        #expect(opened == 1)
    }

    @Test
    func theTitleWrapsInANarrowWidthAndStaysOnOneLineInAWideOne() {
        let view = ClickableTitleView.make()
        view.apply(text: "Revisar el MR pendiente de compass.ui antes de la demo", isUnderlined: false)
        let wide = view.size(fittingWidth: 400)
        let narrow = view.size(fittingWidth: 120)
        #expect(narrow.height > wide.height)
    }

    @Test
    func theUnderlineKeepsTheSelection() {
        let view = ClickableTitleView.make()
        view.apply(text: "Selectable title", isUnderlined: false)
        view.setSelectedRange(NSRange(location: 0, length: 4))
        view.apply(text: "Selectable title", isUnderlined: true)
        #expect(view.selectedRange() == NSRange(location: 0, length: 4))
        #expect(view.textStorage?.attribute(.underlineStyle, at: 0, effectiveRange: nil) != nil)
        view.apply(text: "Selectable title", isUnderlined: false)
        #expect(view.textStorage?.attribute(.underlineStyle, at: 0, effectiveRange: nil) == nil)
    }
}
