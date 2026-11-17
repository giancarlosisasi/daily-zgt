import AppKit
import SwiftUI

enum Theme {
    enum Space {
        static let s1 = TeclaTokens.Space.s1
        static let s2 = TeclaTokens.Space.s2
        static let s3 = TeclaTokens.Space.s3
        static let s4 = TeclaTokens.Space.s4
        static let s5 = TeclaTokens.Space.s5
        static let s6 = TeclaTokens.Space.s6
        static let s7 = TeclaTokens.Space.s7
        static let s8 = TeclaTokens.Space.s8

        static func group(_ layout: PanelLayout) -> CGFloat {
            layout == .window ? s5 : s4
        }
    }

    enum Panel {
        static let width = TeclaTokens.Layout.panelWidth
        static let cornerRadius = TeclaTokens.Radius.panel
        static let padding = Space.s3
        static let spacing = Space.s3
        static let borderWidth: CGFloat = 1
        static let background = Color(TeclaTokens.Panel.bg)
        static let border = Color(TeclaTokens.Panel.line)
        static let side = Color(TeclaTokens.Shadows.panel[0].color)
        static let sideHeight = TeclaTokens.Shadows.panel[0].y
    }

    enum Window {
        static let defaultWidth: CGFloat = 980
        static let defaultHeight: CGFloat = 680
        static let minWidth: CGFloat = 760
        static let minHeight: CGFloat = 520
        static let sidebarMin = TeclaTokens.Layout.sidebarMin
        static let sidebarIdeal = TeclaTokens.Layout.sidebarIdeal
        static let sidebarMax = TeclaTokens.Layout.sidebarMax
        static let sidebarPadding = Space.s3
        static let sidebarTopPadding = Space.s2
        static let sidebarBackground = Color(TeclaTokens.Colors.ground)
        static let readableWidth = TeclaTokens.Layout.readableWidth
        static let detailTopPadding = Space.s6
        static let detailGutter = Space.s5
        static let detailBottomPadding = Space.s5
        static let divider = Color(TeclaTokens.Panel.div)
        static let dividerWidth: CGFloat = 1
        static let dividerGrabWidth = Space.s2
        static let autosaveName = "DailyZGTMainWindow"
        static let sidebarWidthKey = "\(autosaveName).sidebarWidth"

        static func clampedSidebar(_ width: CGFloat) -> CGFloat {
            min(max(width, sidebarMin), sidebarMax)
        }
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
        static let subhead = TeclaFonts.font(TeclaTokens.TextStyles.subhead)

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
        static let panelTopPadding = Space.s2
        static let windowTopPadding = Space.s3
        static let horizontalPadding = Space.s1
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
        static let verticalPadding = Space.s3
        static let horizontalPadding = Space.s2
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
        static let plainText = Text.muted
        static let plainFont = Font.meta
        static let font = Font.metaStrong
        static let verticalPadding: CGFloat = 1
        static let horizontalPadding: CGFloat = 6
        static let radius = TeclaTokens.Radius.chip
    }

    enum Row {
        static let listSpacing: CGFloat = 0
        static let listMaxHeight: CGFloat = 330
        static let minHeight = Space.s5 + Space.s1
        static let windowMinHeight = Space.s6
        static let horizontalPadding = Space.s2
        static let verticalPadding = Space.s2
        static let spacing = Space.s2
        static let radius = TeclaTokens.Radius.row
        static let hoverOverlay = Color(TeclaTokens.Panel.hover)
        static let highlight = Color(TeclaTokens.Panel.hl)
        static let selected = Color(TeclaTokens.Panel.hover2)
        static let caretWidth: CGFloat = 18
        static let caretHeight: CGFloat = 22
        static let caretIconSize: CGFloat = 11
        static let checkboxSize: CGFloat = 16
        static let titleMaxLines = 2
        static let titleSpacing = Space.s1
        static let metaSpacing = Space.s2
        static let metaHeight = (TeclaTokens.TextStyles.panelChip.size * TeclaTokens.TextStyles.panelChip.lineHeight).rounded(.up)
            + Due.verticalPadding * 2
        static let noteIconSize: CGFloat = 11
        static let removeSize: CGFloat = 22
        static let removeIconSize: CGFloat = 12
        static let removeRadius = TeclaTokens.Radius.remove
        static let titleUnderline = Color(TeclaTokens.Panel.titleUnderline)
        static let handleWidth: CGFloat = 12
        static let handleHeight: CGFloat = 22
        static let handleIconSize: CGFloat = 12
        static let handleSpacing: CGFloat = 0
        static let draggedOpacity: Double = 0.35
        static let dropLine = Accent.color
        static let dropLineHeight: CGFloat = 2
        static let dropDotSize: CGFloat = 6
        static let dropLineOffset = (listSpacing + dropDotSize) / 2
    }

    enum DragPreview {
        static let background = Color(TeclaTokens.Panel.bg)
        static let border = Color(TeclaTokens.Panel.line)
        static let borderWidth: CGFloat = 1
        static let radius = TeclaTokens.Radius.row
        static let horizontalPadding: CGFloat = 10
        static let verticalPadding: CGFloat = 8
        static let spacing: CGFloat = 8
        static let maxWidth: CGFloat = 320
        static let grabOffset: CGFloat = 16
        static let startDistance: CGFloat = 3
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
        static let buttonHeight = Space.s5
        static let buttonPadding = Space.s2
        static let buttonRadius = TeclaTokens.Radius.row
        static let buttonIconSize: CGFloat = 13
        static let buttonSpacing = Space.s2
        static let cardBackground = Color(TeclaTokens.Panel.card)
        static let cardBorder = Color(TeclaTokens.Panel.line)
        static let cardPadding = Space.s3
        static let cardSpacing = Space.s2
        static let cardRadius = TeclaTokens.Radius.bar
        static let inputBackground = Color(TeclaTokens.Panel.in)
        static let titleHeight: CGFloat = 30
        static let titlePadding: CGFloat = 10
        static let titleRadius = TeclaTokens.Radius.input
        static let labelWidth = Space.s8
        static let segmentHeight: CGFloat = 24
        static let segmentRadius = TeclaTokens.Radius.input - Segmented.trackPadding
        static let segmentSpacing: CGFloat = 6
        static let segmentTrackRadius = TeclaTokens.Radius.input
        static let hintIconSize: CGFloat = 12
        static let hintSpacing = Space.s2
        static let buttonsSpacing = Space.s2
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

    enum DatePopover {
        static let padding = Space.s3
        static let columnSpacing = Space.s4
        static let rowSpacing = Space.s2
        static let optionWidth: CGFloat = 132
        static let optionHeight = Space.s5 - Space.s1
        static let optionPadding = Space.s2
        static let optionFont = Font.body
        static let optionText = Text.secondary
        static let clearText = Text.muted
        static var fieldFont: NSFont { Font.field }
        static let fieldText = Text.secondary
        static let fieldHeight = Space.s4
        static let fieldPadding = Space.s2
        static let fieldRadius = TeclaTokens.Radius.input
        static let fieldBackground = Color(TeclaTokens.Panel.in)
        static let labelFont = Font.label
        static let labelText = Text.muted
        static let alertFont = Font.meta
        static let alertText = Text.muted
        static let iconSize: CGFloat = 12
        static let iconSpacing = Space.s2
        static let background = Color(TeclaTokens.Panel.bg)
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
        static let spacing: CGFloat = 0
        static let headerFont = Font.labelStrong
        static let countFont = Font.meta
        static let countText = Text.dim
        static let headerHeight: CGFloat = 28
        static let headerPadding = Space.s2
        static let headerRadius = Ghost.radius
        static let headerSpacing = Space.s2
        static let caretSize: CGFloat = 10
        static let rowMinHeight: CGFloat = 34
        static let rowLeadingPadding: CGFloat = 30
        static let rowTrailingPadding = Space.s1
        static let rowVerticalPadding = Space.s2
        static let rowSpacing = Space.s2
        static let checkSize: CGFloat = 12
        static let checkColor = Text.done
        static let title = Text.dim
        static let timeFont = Font.meta
        static let timeText = Text.dim
        static let restoreFont = Font.meta
        static let restoreHeight: CGFloat = 24
        static let restorePadding = Space.s2
        static let restoreRadius = Ghost.radius
        static let restoreSpacing = Space.s1
        static let restoreIconSize: CGFloat = 11
        static let restoreText = Text.ghost
        static let restoreHoverText = Text.primary
        static let historyLinkFont = Font.label
        static let historyLinkText = Text.link
        static let historyLinkHeight: CGFloat = 24
    }

    enum Timing {
        static let undoLifetime = Duration.tecla(TeclaTokens.Durations.undo)
        static let highlightLifetime = Duration.tecla(TeclaTokens.Durations.highlight)
    }
}

extension Theme {
    enum Notes {
        static let spacing = Space.s2
        static let panelMaxHeight = Row.listMaxHeight
        static let windowMinHeight = Space.s8 * 2
        static let panelMinHeight = Space.s8 + Space.s6
        static let pageMinHeight = Space.s8 * 4
        static let padding = Space.s3
        static let radius = TeclaTokens.Radius.input
        static let lineSpacing: CGFloat = 3
        static let background = Color(TeclaTokens.Panel.card)
        static let hint = Text.dim
        static let debounce = Duration.milliseconds(400)
    }
}

extension Theme {
    enum Detail {
        static let spacing = Space.s3
        static let backText = Text.link
        static let backHeight: CGFloat = 26
        static let backLeadingPadding = Space.s1
        static let backTrailingPadding = Space.s2
        static let backRadius = Ghost.radius
        static let backSpacing: CGFloat = 2
        static let backChevronSize: CGFloat = 14
        static let deleteSize: CGFloat = 26
        static let deleteIconSize: CGFloat = 14
        static let deleteRadius = Ghost.radius
        static let headSpacing = Space.s2
        static let titleFont = Font.title
        static let windowTitleFont = Font.subhead
        static let titleInset: CGFloat = 6
        static let titleVerticalInset = Space.s1
        static let titleRadius = TeclaTokens.Radius.input
        static let titleHoverBackground = Color(TeclaTokens.Panel.in)
        static let chipFont = Font.metaStrong
        static let chipHorizontalPadding: CGFloat = 7
        static let chipVerticalPadding: CGFloat = 1
        static let chipRadius = TeclaTokens.Radius.chip
        static let chipSpacing = Space.s2
        static let doneStateBackground = Color(TeclaTokens.Panel.doneBg)
        static let doneStateText = Color(TeclaTokens.Panel.doneText)
        static let labelWidth = Space.s8
        static let labelFont = Font.label
        static let labelText = Text.muted
        static let propertyHeight = Space.s5
        static let propertySpacing = Space.s1
        static let valueFont = Font.body
        static let valueText = Text.secondary
        static let valueDim = Text.dim
        static let valueLate = Due.overdueText
        static let valuePadding = Space.s2
        static let valueHeight = Space.s5 - Space.s1
        static let valueSpacing = Space.s2
        static let valueIconSize: CGFloat = 12
        static let valueCaretSize: CGFloat = 9
        static let menuPadding = Space.s1
        static let menuWidth: CGFloat = 168
        static let menuRowHeight = Space.s5 - Space.s1
        static let menuSelected = Color(TeclaTokens.Panel.hover2)
        static let alertSpacing = Space.s2
        static let alertIconSize: CGFloat = 12
        static let sectionSpacing = Space.s2
        static let sectionTitleFont = Font.labelStrong
        static let sectionTitleText = Text.muted
        static let sectionCountText = Text.dim
        static let markDoneHeight: CGFloat = 30
        static let markDoneRadius = TeclaTokens.Radius.row
        static let markDoneText = Color(TeclaTokens.Panel.doneText)
        static let markDoneFont = Font.bodyStrong
        static let markDoneIconSize: CGFloat = 13
        static let markDoneSpacing = Space.s2
        static let markDonePadding = Space.s3
        static let created = Text.dim
    }
}

extension Theme {
    enum SubtaskList {
        static let rowMinHeight = Space.s5
        static let rowSpacing = Space.s2
        static let checkboxSize: CGFloat = 14
        static let font = Font.body
        static let openText = Text.secondary
        static let doneText = Text.dim
        static let addText = Text.ghost
        static let addIconSize: CGFloat = 11
        static let inputHeight = Space.s5 - Space.s1
        static let inputPadding = Space.s2
        static let inputRadius = TeclaTokens.Radius.input
        static let inputBackground = Color(TeclaTokens.Panel.in)
        static let rowListLeading: CGFloat = 50
        static let rowListTrailing = Space.s1
        static let rowListBottom = Space.s2
    }
}

extension Theme {
    enum MenuBar {
        static let spacing: CGFloat = 5
        static let font = Font.labelStrong
        static let titleFont = Font.label
        static let badgeFont = Font.meta
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
        static let background = Color(TeclaTokens.Panel.card)
        static let border = Color(TeclaTokens.Panel.div)
        static let radius = TeclaTokens.Radius.bar
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
        static let dayFont = DoneSection.headerFont
        static let dayText = Text.muted
        static let countFont = Font.meta
        static let countText = Text.dim
        static let dayBottomPadding = Space.s1
        static let dayHorizontalPadding = Space.s2
        static let rowLeadingPadding = Space.s2
        static let titleText = Text.secondary
        static let emptyText = Text.muted
        static let emptyVerticalPadding = EmptyList.verticalPadding
        static let emptyHorizontalPadding = EmptyList.horizontalPadding
        static let headerBackground = Panel.background
        static let backTitleSpacing = Space.s1
    }
}

extension Theme {
    enum Filter {
        static let titleSpacing = Space.s1
        static let panelTitleFont = Font.title
        static let windowTitleFont = Font.subhead
        static let titleText = Text.strong
        static let subtitleFont = Font.label
        static let subtitleText = Text.muted
        static let subtitleSpacing = Space.s1
        static let stepSize = Ghost.height
        static let stepIconSize: CGFloat = 12
        static let stepText = Text.muted
        static let keyHeight = Key.height
        static let keyRadius = Key.radius
        static let keyPadding = Space.s2
        static let keySpacing = Space.s1
        static let keyIconSize: CGFloat = 13
        static let keyCaretSize = Detail.valueCaretSize
        static let linkFont = Font.label
        static let linkText = Due.overdueText
        static let linkHeight = Ghost.height
        static let linkPadding = Space.s2
        static let linkBottomPadding = Space.s1
        static let groupFont = Font.labelStrong
        static let groupText = Text.muted
        static let groupBottomPadding = Space.s1
        static let groupHorizontalPadding = Space.s2
        static let emptyFont = Font.body
        static let emptyText = Text.muted
        static let emptyTopPadding = Space.s4
        static let emptyBottomPadding = Space.s2
        static let emptyHorizontalPadding = Space.s2
        static let popoverPadding = DatePopover.padding
        static let popoverColumnSpacing = DatePopover.columnSpacing
        static let popoverRowSpacing = DatePopover.rowSpacing
        static let optionWidth = DatePopover.optionWidth
        static let optionHeight = DatePopover.optionHeight
        static let optionPadding = DatePopover.optionPadding
        static let optionFont = DatePopover.optionFont
        static let optionText = DatePopover.optionText
        static let optionCountFont = Font.meta
        static let optionCountText = Text.dim
        static let optionSelected = Detail.menuSelected
        static let optionRadius = Ghost.radius
        static let hintFont = Font.meta
        static let hintText = Text.muted
        static let background = DatePopover.background

        static func groupTopPadding(_ layout: PanelLayout) -> CGFloat {
            layout == .window ? Space.s4 : Space.s3
        }
    }
}
