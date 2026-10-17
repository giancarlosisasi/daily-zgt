import AppKit
import SwiftUI

enum Theme {
    enum Panel {
        static let width: CGFloat = 360
        static let cornerRadius = TeclaTokens.Radius.panel
        static let padding: CGFloat = 10
        static let spacing: CGFloat = 10
        static let borderWidth: CGFloat = 1
        static let background = Color(TeclaTokens.Panel.bg)
        static let border = Color(TeclaTokens.Panel.line)
        static let side = Color(TeclaTokens.Shadows.panel[0].color)
        static let sideHeight = TeclaTokens.Shadows.panel[0].y
    }

    enum Text {
        static let primary = Color(TeclaTokens.Panel.text)
        static let strong = Color(TeclaTokens.Panel.strong)
        static let secondary = Color(TeclaTokens.Panel.text2)
        static let ghost = Color(TeclaTokens.Panel.ghost)
        static let muted = Color(TeclaTokens.Panel.muted)
        static let dim = Color(TeclaTokens.Panel.dim)
        static let link = Color(TeclaTokens.Panel.link)
        static let done = Color(TeclaTokens.Panel.done)
    }

    enum Font {
        static let body = TeclaFonts.font(TeclaTokens.TextStyles.panel)
        static let bodyStrong = TeclaFonts.font(TeclaTokens.TextStyles.panel, weight: .semibold)
        static let topTab = TeclaFonts.font(TeclaTokens.TextStyles.panel, weight: .semibold)
        static let scopeTab = TeclaFonts.font(TeclaTokens.TextStyles.panelLabel)
        static let label = TeclaFonts.font(TeclaTokens.TextStyles.panelLabel)
        static let labelStrong = TeclaFonts.font(TeclaTokens.TextStyles.panelLabel, weight: .semibold)
        static let footer = TeclaFonts.font(TeclaTokens.TextStyles.panelLabel)
        static let meta = TeclaFonts.font(TeclaTokens.TextStyles.panelMeta)
        static let metaStrong = TeclaFonts.font(TeclaTokens.TextStyles.panelChip)
        static let title = TeclaFonts.font(TeclaTokens.TextStyles.panelTitle)

        static var rowTitle: NSFont { TeclaFonts.nsFont(TeclaTokens.TextStyles.panel) }
        static var field: NSFont { TeclaFonts.nsFont(TeclaTokens.TextStyles.panelLabel, tabularDigits: true) }
        static let rowTitleLineHeight = TeclaTokens.TextStyles.panel.size * TeclaTokens.TextStyles.panel.lineHeight
    }

    enum Motion {
        static let press = Animation.tecla(TeclaTokens.Easings.press)
        static let out = Animation.tecla(TeclaTokens.Easings.out)
        static let `in` = Animation.tecla(TeclaTokens.Easings.in)
        static let spring = Animation.tecla(TeclaTokens.Springs.default)
        static let momentum = Animation.tecla(TeclaTokens.Springs.momentum)
        static let pressSpring = Animation.tecla(TeclaTokens.Springs.press)
        static let fast = TeclaTokens.Durations.fast
        static let base = TeclaTokens.Durations.base
        static let slow = TeclaTokens.Durations.slow
        static let panelOpen = TeclaTokens.Durations.panelOpen
        static let alert = TeclaTokens.Durations.alert
        static let fade = Animation.easeInOut(duration: TeclaTokens.Durations.fast)
        static let panelPop = Animation.tecla(TeclaTokens.Easings.out, duration: TeclaTokens.Durations.panelOpen)
        static let slowOut = Animation.tecla(TeclaTokens.Easings.out, duration: TeclaTokens.Durations.slow)
    }

    enum MotionShape {
        static let popOffset: CGFloat = 8
        static let popScale: CGFloat = 0.96
        static let rowInOffset: CGFloat = 4
        static let rowOutOffset: CGFloat = 28
        static let slideOffset: CGFloat = 18
        static let caretOpenDegrees: Double = 90
        static let ringAngles: [Double] = [0, 14, -12, 8, -4, 0]
        static let ringAnchor = UnitPoint(x: 0.5, y: 0.1)
    }

    enum Key {
        static let face = Color(TeclaTokens.Key.face)
        static let side = Color(TeclaTokens.Shadows.panelKey[0].color)
        static let text = Text.primary
        static let accentFace = Color(TeclaTokens.Key.accentFace)
        static let accentSide = Color(TeclaTokens.Shadows.panelAccentKey[0].color)
        static let accentText = Color(TeclaTokens.Panel.onAccent)
        static let selectedFace = Color(TeclaTokens.Key.selectedFace)
        static let pressedTint = Color(TeclaTokens.Panel.pressTint)
        static let sideHeight = TeclaTokens.Shadows.panelKey[0].y
        static let travel = TeclaTokens.Key.panelTravel
        static let radius = TeclaTokens.Radius.panelControl
        static let height: CGFloat = 26
    }

    enum Segmented {
        static let selectedBackground = Key.selectedFace
        static let selectedText = Color(TeclaTokens.Panel.segT)
        static let unselectedText = Text.muted
        static let hoverText = Color(TeclaTokens.Panel.segT)
        static let trackPadding: CGFloat = 2
        static let trackSpacing: CGFloat = 2

        enum Top {
            static let track = Color(TeclaTokens.Panel.track)
            static let trackRadius = TeclaTokens.Radius.track
            static let buttonHeight: CGFloat = 26
            static let buttonRadius = TeclaTokens.Radius.segment
        }

        enum Scope {
            static let track = Color(TeclaTokens.Panel.track2)
            static let trackRadius = TeclaTokens.Radius.track
            static let buttonHeight: CGFloat = 22
            static let buttonRadius = TeclaTokens.Radius.segment
            static let buttonPadding: CGFloat = 10
        }
    }

    enum Ghost {
        static let hoverBackground = Color(TeclaTokens.Panel.hover2)
        static let radius = TeclaTokens.Radius.ghost
        static let height: CGFloat = 24
        static let padding: CGFloat = 8
    }

    enum Footer {
        static let divider = Color(TeclaTokens.Panel.div)
        static let dividerHeight: CGFloat = 1
        static let topPadding: CGFloat = 8
        static let horizontalPadding: CGFloat = 4
        static let actionSpacing: CGFloat = 2
        static let text = Text.muted
        static let bellText = Text.muted
        static let gearText = Text.muted
        static let gearOpenText = Text.primary
        static let quitText = Text.ghost
        static let iconButtonWidth: CGFloat = 26
        static let iconSize: CGFloat = 13
    }

    enum EmptyList {
        static let text = Text.muted
        static let verticalPadding: CGFloat = 14
        static let horizontalPadding: CGFloat = 8
    }

    enum Accent {
        static let color = Color(TeclaTokens.Panel.accent)
        static let onColor = Color(TeclaTokens.Panel.onAccent)
        static let caret = Text.primary
        static let focusRing = Color(TeclaTokens.Panel.focus)
        static let focusRingWidth: CGFloat = 2
    }

    enum Level {
        static let high = Color(TeclaTokens.Panel.high)
        static let medium = Color(TeclaTokens.Panel.medium)
        static let low = Color(TeclaTokens.Panel.low)
        static let unfilled = Color(TeclaTokens.Panel.lvOff)
        static let barWidth = TeclaTokens.Size.levelBarWidth
        static let barSpacing = TeclaTokens.Size.levelBarGap
        static let barRadius = TeclaTokens.Size.levelBarRadius
        static let barHeights: [CGFloat] = [5, 8, 11]
        static let boxHeight: CGFloat = 11
    }

    enum Due {
        static let overdueText = Color(TeclaTokens.Panel.lateT)
        static let overdueBackground = Color(TeclaTokens.Panel.lateBg)
        static let soonText = Color(TeclaTokens.Panel.soonT)
        static let soonBackground = Color(TeclaTokens.Panel.soonBg)
        static let laterText = Color(TeclaTokens.Panel.laterT)
        static let laterBackground = Color(TeclaTokens.Panel.laterBg)
        static let font = Font.metaStrong
        static let verticalPadding: CGFloat = 1
        static let horizontalPadding: CGFloat = 6
        static let radius = TeclaTokens.Radius.chip
    }

    enum Row {
        static let listSpacing: CGFloat = 2
        static let listMaxHeight: CGFloat = 330
        static let sectionSpacing: CGFloat = 8
        static let minHeight: CGFloat = 36
        static let horizontalPadding: CGFloat = 4
        static let spacing: CGFloat = 8
        static let radius = TeclaTokens.Radius.row
        static let hoverOverlay = Color(TeclaTokens.Panel.hover)
        static let highlight = Color(TeclaTokens.Panel.hl)
        static let caretWidth: CGFloat = 18
        static let caretHeight: CGFloat = 22
        static let caretIconSize: CGFloat = 11
        static let checkboxSize: CGFloat = 16
        static let titleVerticalPadding: CGFloat = 5
        static let titleSpacing: CGFloat = 2
        static let metaSpacing: CGFloat = 6
        static let noteIconSize: CGFloat = 11
        static let removeSize: CGFloat = 22
        static let removeIconSize: CGFloat = 12
        static let removeRadius = TeclaTokens.Radius.remove
        static let titleUnderline = Color(TeclaTokens.Panel.titleUnderline)
    }

    enum Checkbox {
        static let radius = TeclaTokens.Radius.checkbox
        static let fill = Key.face
        static let border = Color(TeclaTokens.Panel.cb)
        static let borderWidth = TeclaTokens.Size.checkboxLine
        static let checkedFill = Accent.color
        static let check = Accent.onColor
        static let checkRatio: CGFloat = 0.625
    }

    enum AllDone {
        static let color = Text.done
        static let circleOpacity: Double = 0.38
        static let lineWidth: CGFloat = 2.4
        static let size: CGFloat = 36
        static let spacing: CGFloat = 8
        static let topPadding: CGFloat = 18
        static let bottomPadding: CGFloat = 14
        static let horizontalPadding: CGFloat = 8
    }

    enum NewPriority {
        static let buttonBorder = Color(TeclaTokens.Panel.dash)
        static let buttonHeight: CGFloat = 32
        static let buttonPadding: CGFloat = 8
        static let buttonRadius = TeclaTokens.Radius.row
        static let buttonIconSize: CGFloat = 13
        static let buttonSpacing: CGFloat = 8
        static let cardBackground = Color(TeclaTokens.Panel.card)
        static let cardBorder = Color(TeclaTokens.Panel.line)
        static let cardPadding: CGFloat = 10
        static let cardSpacing: CGFloat = 8
        static let cardRadius = TeclaTokens.Radius.bar
        static let inputBackground = Color(TeclaTokens.Panel.in)
        static let inputBorder = Color(TeclaTokens.Panel.line)
        static let titleHeight: CGFloat = 30
        static let titlePadding: CGFloat = 10
        static let titleRadius = TeclaTokens.Radius.input
        static let labelWidth: CGFloat = 64
        static let segmentHeight: CGFloat = 24
        static let segmentRadius = TeclaTokens.Radius.input - Segmented.trackPadding
        static let segmentSpacing: CGFloat = 6
        static let segmentTrackRadius = TeclaTokens.Radius.input
        static let dateHeight: CGFloat = 28
        static let datePadding: CGFloat = 8
        static let dateRadius = TeclaTokens.Radius.input
        static let dateText = Text.secondary
        static let datePickerInset: CGFloat = 3
        static let dateIconSize: CGFloat = 12
        static let dateClearIconSize: CGFloat = 10
        static let dateClearSize: CGFloat = 20
        static let hintIconSize: CGFloat = 12
        static let hintSpacing: CGFloat = 6
        static let buttonsSpacing: CGFloat = 6
        static let actionHeight = Key.height
        static let actionRadius = Key.radius
        static let cancelPadding: CGFloat = 10
        static let addPadding: CGFloat = 12
    }
}

extension Theme {
    enum Confirm {
        static let background = Color(TeclaTokens.Panel.doneBg)
        static let border = Color(TeclaTokens.Panel.doneLine)
        static let title = Color(TeclaTokens.Panel.doneTitle)
        static let hint = Text.muted
        static let titleFont = Font.labelStrong
        static let hintFont = Font.meta
        static let topMargin: CGFloat = 2
        static let leadingMargin: CGFloat = 30
        static let trailingMargin: CGFloat = 4
        static let bottomMargin: CGFloat = 4
        static let verticalPadding: CGFloat = 7
        static let leadingPadding: CGFloat = 10
        static let trailingPadding: CGFloat = 8
        static let radius = TeclaTokens.Radius.bar
        static let spacing: CGFloat = 8
        static let textSpacing: CGFloat = 1
        static let buttonHeight = Key.height
        static let buttonPadding: CGFloat = 10
        static let buttonRadius = Key.radius
        static let buttonFont = Font.label
        static let doneFont = Font.labelStrong
        static let checkSize: CGFloat = 12
        static let checkSpacing: CGFloat = 5
    }

    enum Undo {
        static let background = Color(TeclaTokens.Panel.undo)
        static let text = Text.secondary
        static let check = Text.done
        static let button = Text.link
        static let line = Text.link
        static let lineHeight = TeclaTokens.Size.undoLine
        static let font = Font.label
        static let buttonFont = Font.labelStrong
        static let verticalPadding: CGFloat = 6
        static let leadingPadding: CGFloat = 10
        static let trailingPadding: CGFloat = 6
        static let radius = TeclaTokens.Radius.bar
        static let spacing: CGFloat = 8
        static let checkSize: CGFloat = 12
        static let buttonHeight: CGFloat = 24
        static let buttonPadding: CGFloat = 8
        static let buttonRadius = Ghost.radius
    }

    enum DoneSection {
        static let divider = Color(TeclaTokens.Panel.div)
        static let dividerHeight: CGFloat = 1
        static let topPadding: CGFloat = 6
        static let spacing: CGFloat = 2
        static let headerFont = Font.labelStrong
        static let headerHeight: CGFloat = 28
        static let headerPadding: CGFloat = 8
        static let headerRadius = Ghost.radius
        static let headerSpacing: CGFloat = 6
        static let caretSize: CGFloat = 10
        static let rowMinHeight: CGFloat = 34
        static let rowLeadingPadding: CGFloat = 30
        static let rowTrailingPadding: CGFloat = 4
        static let rowSpacing: CGFloat = 10
        static let checkSize: CGFloat = 12
        static let checkColor = Text.done
        static let title = Text.dim
        static let restoreFont = Font.meta
        static let restoreHeight: CGFloat = 24
        static let restorePadding: CGFloat = 8
        static let restoreRadius = Key.radius
        static let restoreSpacing: CGFloat = 4
        static let restoreIconSize: CGFloat = 11
        static let restoreText = Text.ghost
    }

    enum Timing {
        static let undoLifetime = Duration.tecla(TeclaTokens.Durations.undo)
        static let highlightLifetime = Duration.tecla(TeclaTokens.Durations.highlight)
    }
}

extension Theme {
    enum Notes {
        static let spacing: CGFloat = 6
        static let height: CGFloat = 200
        static let padding: CGFloat = 10
        static let borderWidth: CGFloat = 1
        static let editorInset: CGFloat = 5
        static let radius = TeclaTokens.Radius.bar
        static let lineSpacing: CGFloat = 3
        static let background = Color(TeclaTokens.Panel.card)
        static let border = Color(TeclaTokens.Panel.line)
        static let placeholder = Text.dim
        static let hint = Text.dim
        static let debounce = Duration.milliseconds(400)
        static let syncInterval = Duration.seconds(30)
    }
}

extension Theme {
    enum Detail {
        static let spacing: CGFloat = 12
        static let backText = Text.link
        static let backHeight: CGFloat = 26
        static let backLeadingPadding: CGFloat = 4
        static let backTrailingPadding: CGFloat = 8
        static let backRadius = Ghost.radius
        static let backSpacing: CGFloat = 2
        static let backChevronSize: CGFloat = 14
        static let deleteSize: CGFloat = 26
        static let deleteIconSize: CGFloat = 14
        static let deleteRadius = Ghost.radius
        static let headSpacing: CGFloat = 6
        static let titleFont = Font.title
        static let titleHeight: CGFloat = 34
        static let titleInset: CGFloat = 6
        static let titleRadius = TeclaTokens.Radius.input
        static let titleHoverBorder = Color(TeclaTokens.Panel.line)
        static let chipFont = Font.metaStrong
        static let chipHorizontalPadding: CGFloat = 7
        static let chipVerticalPadding: CGFloat = 1
        static let chipRadius = TeclaTokens.Radius.chip
        static let chipSpacing: CGFloat = 6
        static let stateBackground = Color(TeclaTokens.Panel.laterBg)
        static let stateText = Color(TeclaTokens.Panel.laterT)
        static let doneStateBackground = Color(TeclaTokens.Panel.doneBg)
        static let doneStateText = Color(TeclaTokens.Panel.doneText)
        static let boxBackground = Color(TeclaTokens.Panel.card)
        static let boxBorder = Color(TeclaTokens.Panel.div)
        static let boxPadding: CGFloat = 10
        static let boxRadius = TeclaTokens.Radius.bar
        static let boxSpacing: CGFloat = 8
        static let labelWidth: CGFloat = 84
        static let valueFont = Font.label
        static let alertSpacing: CGFloat = 6
        static let alertIconSize: CGFloat = 12
        static let sectionSpacing: CGFloat = 4
        static let sectionTitleFont = Font.metaStrong
        static let sectionTitleTracking: CGFloat = 0.33
        static let markDoneHeight: CGFloat = 30
        static let markDoneRadius = TeclaTokens.Radius.row
        static let markDoneText = Color(TeclaTokens.Panel.doneText)
        static let markDoneFont = Font.bodyStrong
        static let markDoneIconSize: CGFloat = 13
        static let markDoneSpacing: CGFloat = 6
        static let created = Text.dim
    }
}

extension Theme {
    enum SubtaskList {
        static let rowMinHeight: CGFloat = 26
        static let rowSpacing: CGFloat = 8
        static let checkboxSize: CGFloat = 14
        static let font = Font.label
        static let openText = Text.secondary
        static let doneText = Text.dim
        static let inputHeight: CGFloat = 26
        static let inputPadding: CGFloat = 8
        static let inputRadius = TeclaTokens.Radius.input
        static let inputBackground = Color(TeclaTokens.Panel.card)
        static let inputBorder = Color(TeclaTokens.Panel.line)
        static let rowListSpacing: CGFloat = 1
        static let rowListInputTop: CGFloat = 2
        static let rowListLeading: CGFloat = 50
        static let rowListTrailing: CGFloat = 4
        static let rowListBottom: CGFloat = 6
        static let detailSpacing: CGFloat = 4
    }

    enum PriorityNoteArea {
        static let height: CGFloat = 110
        static let horizontalPadding: CGFloat = 10
        static let verticalPadding: CGFloat = 9
    }
}

extension Theme {
    enum MenuBar {
        static let spacing: CGFloat = 5
        static let font = Font.labelStrong
        static let titleFont = Font.label
    }

    enum AlertsOff {
        static let link = Text.link
        static let linkFont = Font.labelStrong
        static let spacing: CGFloat = 6
        static let stackedSpacing: CGFloat = 2
    }
}

extension Theme {
    enum Switch {
        static let width: CGFloat = 52
        static let height: CGFloat = 30
        static let inset: CGFloat = 3
        static let knobSize: CGFloat = 24
        static let knobRadius: CGFloat = 8
        static let wellHeight: CGFloat = 2
        static let offTrack = Color(TeclaTokens.Colors.surface2)
        static let onTrack = Color(TeclaTokens.Colors.fill)
        static let knob = Color(TeclaTokens.Colors.knob)
        static let well = Segmented.Top.track
        static var travel: CGFloat { width - knobSize - inset * 2 }
    }

    enum Limit {
        static let noticeFont = Font.meta
        static let noticeText = Text.secondary
    }

    enum Settings {
        static let spacing: CGFloat = 6
        static let rowPadding: CGFloat = 10
        static let rowSpacing: CGFloat = 8
        static let controlSpacing: CGFloat = 12
        static let textSpacing: CGFloat = 2
        static let noteSpacing: CGFloat = 6
        static let background = Detail.boxBackground
        static let border = Detail.boxBorder
        static let radius = Detail.boxRadius
        static let titleFont = Font.body
        static let detailFont = Font.meta
        static let noteFont = Font.meta
        static let linkFont = Font.metaStrong
        static let title = Text.primary
        static let detail = Text.muted
        static let note = Text.secondary
        static let link = Text.link
    }
}

extension Theme {
    enum Capture {
        static let padding: CGFloat = 12
        static let spacing: CGFloat = 8
        static let barSpacing: CGFloat = 6
        static let markSize: CGFloat = 14
        static let barFont = Font.labelStrong
        static let barText = Text.muted
        static let markText = Text.primary
        static let inputHeight: CGFloat = 36
        static let inputRadius = TeclaTokens.Radius.track
        static let inputPadding: CGFloat = 12
        static let inputFont = TeclaFonts.font(TeclaTokens.TextStyles.panelCapture)
        static let focusRing = Color(TeclaTokens.Panel.captureFocus)
        static let hintFont = Font.meta
        static let hintText = Text.muted
        static let topInset: CGFloat = 80
        static let recorderWidth: CGFloat = 130
    }
}

extension Theme {
    enum History {
        static let rowHeight = DoneSection.headerHeight
        static let rowRadius = DoneSection.headerRadius
        static let rowLeadingPadding = DoneSection.rowLeadingPadding
        static let rowTrailingPadding = DoneSection.headerPadding
        static let rowSpacing: CGFloat = 8
        static let rowFont = Font.label
        static let countFont = Font.meta
        static let countText = Text.dim
        static let caretSize = DoneSection.caretSize
        static let daySpacing: CGFloat = 12
        static let dayRowSpacing = DoneSection.spacing
        static let dayFont = DoneSection.headerFont
        static let dayText = Text.muted
        static let dayPadding = DoneSection.headerPadding
        static let doneRowLeadingPadding: CGFloat = 8
        static let titleFont = Font.label
        static let titleText = Text.muted
        static let emptyText = Text.muted
        static let emptyVerticalPadding = EmptyList.verticalPadding
        static let emptyHorizontalPadding = EmptyList.horizontalPadding
    }
}
