import AppKit
import Foundation
import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct ThemeTests {
    @Test
    func theThemeRolesUseTheTokens() {
        #expect(Theme.Panel.background == Color(TeclaTokens.Panel.bg))
        #expect(Theme.Panel.cornerRadius == TeclaTokens.Radius.panel)
        #expect(Theme.Panel.side == Color(TeclaTokens.Shadows.panel[0].color))
        #expect(Theme.Panel.sideHeight == TeclaTokens.Shadows.panel[0].y)
        #expect(Theme.Level.high == Color(TeclaTokens.Panel.high))
        #expect(Theme.Level.medium == Color(TeclaTokens.Panel.medium))
        #expect(Theme.Level.low == Color(TeclaTokens.Panel.low))
        #expect(Theme.Due.overdueText == Color(TeclaTokens.Panel.lateT))
        #expect(Theme.Due.soonBackground == Color(TeclaTokens.Panel.soonBg))
        #expect(Theme.Due.radius == TeclaTokens.Radius.chip)
        #expect(Theme.Row.radius == TeclaTokens.Radius.row)
        #expect(Theme.Row.highlight == Color(TeclaTokens.Panel.hl))
        #expect(Theme.Checkbox.radius == TeclaTokens.Radius.checkbox)
        #expect(Theme.Checkbox.checkedFill == Color(TeclaTokens.Panel.accent))
        #expect(Theme.Confirm.background == Color(TeclaTokens.Panel.doneBg))
        #expect(Theme.Confirm.radius == TeclaTokens.Radius.bar)
        #expect(Theme.Undo.line == Color(TeclaTokens.Panel.link))
        #expect(Theme.Segmented.Top.trackRadius == TeclaTokens.Radius.track)
        #expect(Theme.Key.radius == TeclaTokens.Radius.panelControl)
        #expect(Theme.Timing.undoLifetime == .tecla(TeclaTokens.Durations.undo))
        #expect(Theme.Timing.highlightLifetime == .tecla(TeclaTokens.Durations.highlight))
    }

    @Test
    func theSizesAndTheTintsOfTheThemeComeFromTokens() {
        #expect(Theme.Level.barWidth == TeclaTokens.Size.levelBarWidth)
        #expect(Theme.Level.barRadius == TeclaTokens.Size.levelBarRadius)
        #expect(Theme.Level.barSpacing == TeclaTokens.Size.levelBarGap)
        #expect(Theme.Checkbox.borderWidth == TeclaTokens.Size.checkboxLine)
        #expect(Theme.Undo.lineHeight == TeclaTokens.Size.undoLine)
        #expect(Theme.Ghost.radius == TeclaTokens.Radius.ghost)
        #expect(Theme.Row.removeRadius == TeclaTokens.Radius.remove)
        #expect(Theme.Row.titleUnderline == Color(TeclaTokens.Panel.titleUnderline))
        #expect(Theme.Key.pressedTint == Color(TeclaTokens.Panel.pressTint))
    }

    @Test
    func theMetaLineIsRegularAndTheChipIsSemibold() {
        let meta = TeclaFonts.ctFont(TeclaTokens.TextStyles.panelMeta)
        let chip = TeclaFonts.ctFont(TeclaTokens.TextStyles.panelChip)

        #expect(TeclaFonts.weight(of: meta) == 400)
        #expect(TeclaFonts.weight(of: chip) == 600)
    }

    @Test
    func theCaptureFieldIs14PointsWithTheYellowFocusRing() {
        let field = TeclaFonts.ctFont(TeclaTokens.TextStyles.panelCapture)

        #expect(TeclaTokens.TextStyles.panelCapture.size == 14)
        #expect(CTFontGetSize(field) == 14)
        #expect(TeclaFonts.weight(of: field) == 400)
        #expect(TeclaTokens.TextStyles.panelCapture.trackingEm == 0)
        #expect(Theme.Capture.focusRing == Color(TeclaTokens.Panel.captureFocus))
        #expect(TeclaTokens.Panel.captureFocus == TeclaTokens.Colors.focus)
        #expect(Theme.Capture.focusRing != Theme.Accent.focusRing)
    }

    @Test
    func theTypeTokensOfThePanelHaveNoTracking() {
        let styles = [
            TeclaTokens.TextStyles.panel,
            TeclaTokens.TextStyles.panelLabel,
            TeclaTokens.TextStyles.panelMeta,
            TeclaTokens.TextStyles.panelChip,
            TeclaTokens.TextStyles.panelTitle,
        ]
        for style in styles {
            #expect(style.trackingEm == 0)
        }
    }

    @Test
    func violetIsOnlyOnTheKeyThatCommits() {
        let violet = Color(TeclaTokens.Panel.accent)

        #expect(KeyRole.primary.face == violet)
        #expect(KeyRole.graphite.face != violet)
        #expect(Theme.Segmented.selectedBackground != violet)
        #expect(Theme.Row.highlight != violet)
        #expect(Theme.Undo.button != violet)
    }

    @Test
    func eachThemeFontUsesTheTextFamily() {
        let styles = [
            TeclaTokens.TextStyles.panel,
            TeclaTokens.TextStyles.panelLabel,
            TeclaTokens.TextStyles.panelMeta,
            TeclaTokens.TextStyles.panelTitle,
        ]
        for style in styles {
            #expect(style.family == TeclaTokens.Fonts.text)
            #expect(style.family.weights.contains(style.weight))
        }
        #expect(Theme.Font.rowTitle.familyName == TeclaTokens.Fonts.text.family)
        #expect(Theme.Font.rowTitle.pointSize == TeclaTokens.TextStyles.panel.size)
        #expect(Theme.Font.field.familyName == TeclaTokens.Fonts.text.family)
    }

    @Test
    func theWeightsOfTheThemeAreInTheTextFamily() {
        let used: [TeclaWeight] = [.regular, .semibold, .bold]
        for weight in used {
            #expect(TeclaTokens.Fonts.text.weights.contains(weight.rawValue))
        }
    }
}
