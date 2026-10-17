import CoreGraphics

enum TeclaTokens {
    static let name = "Tecla"
    static let sourceDigest = "d86173cb6daaf3b66e12e2fca352f55e39bd45bd5c03ebe4a6574a67d068385b"
    static let outputDigest = "4965843c0c07c725f56ff9ab419127469e919699edf47c2521f3333b8ccce6b9"

    enum Colors {
        static let ground = TeclaColor(hex: 0x17171A, alpha: 1.0)
        static let surface = TeclaColor(hex: 0x222226, alpha: 1.0)
        static let surface2 = TeclaColor(hex: 0x303036, alpha: 1.0)
        static let line = TeclaColor(hex: 0xFFFFFF, alpha: 0.13)
        static let line2 = TeclaColor(hex: 0xFFFFFF, alpha: 0.55)
        static let text = TeclaColor(hex: 0xF4F3F7, alpha: 1.0)
        static let text2 = TeclaColor(hex: 0xA9A7B4, alpha: 1.0)
        static let accent = TeclaColor(hex: 0xFFBE0B, alpha: 1.0)
        static let fill = TeclaColor(hex: 0x8338EC, alpha: 1.0)
        static let onFill = TeclaColor(hex: 0xFFFFFF, alpha: 1.0)
        static let band = TeclaColor(hex: 0x8338EC, alpha: 1.0)
        static let onBand = TeclaColor(hex: 0xFFFFFF, alpha: 1.0)
        static let focus = TeclaColor(hex: 0xFFBE0B, alpha: 1.0)
        static let knob = TeclaColor(hex: 0xFFFFFF, alpha: 1.0)
        static let mbBg = TeclaColor(hex: 0x0C0C0E, alpha: 1.0)
        static let key = TeclaColor(hex: 0x3A3A42, alpha: 1.0)
        static let keySide = TeclaColor(hex: 0x0C0C0E, alpha: 1.0)
        static let keyT = TeclaColor(hex: 0xF4F3F7, alpha: 1.0)
        static let fillSide = TeclaColor(hex: 0x4F1AA8, alpha: 1.0)
        static let onBlue = TeclaColor(hex: 0x06112A, alpha: 1.0)
        static let mbText = TeclaColor(hex: 0xF5F5F7, alpha: 1.0)
        static let tileShade = TeclaColor(hex: 0x000000, alpha: 0.18)
    }

    enum Palette {
        static let violet = TeclaColor(hex: 0x8338EC, alpha: 1.0)
        static let blue = TeclaColor(hex: 0x3A86FF, alpha: 1.0)
        static let yellow = TeclaColor(hex: 0xFFBE0B, alpha: 1.0)
        static let orange = TeclaColor(hex: 0xFB5607, alpha: 1.0)
        static let rose = TeclaColor(hex: 0xFF006E, alpha: 1.0)
    }

    enum Panel {
        static let bg = TeclaColor(hex: 0x222226, alpha: 1.0)
        static let solid = TeclaColor(hex: 0x222226, alpha: 1.0)
        static let line = TeclaColor(hex: 0xFFFFFF, alpha: 0.13)
        static let text = TeclaColor(hex: 0xF4F3F7, alpha: 1.0)
        static let strong = TeclaColor(hex: 0xFFFFFF, alpha: 1.0)
        static let text2 = TeclaColor(hex: 0xDAD9E1, alpha: 1.0)
        static let ghost = TeclaColor(hex: 0xC8C6D1, alpha: 1.0)
        static let muted = TeclaColor(hex: 0xA3A1AD, alpha: 1.0)
        static let dim = TeclaColor(hex: 0x8F8D9A, alpha: 1.0)
        static let accent = TeclaColor(hex: 0x8338EC, alpha: 1.0)
        static let onAccent = TeclaColor(hex: 0xFFFFFF, alpha: 1.0)
        static let link = TeclaColor(hex: 0x6BA6FF, alpha: 1.0)
        static let focus = TeclaColor(hex: 0x3A86FF, alpha: 0.8)
        static let captureFocus = TeclaColor(hex: 0xFFBE0B, alpha: 1.0)
        static let track = TeclaColor(hex: 0x000000, alpha: 0.3)
        static let track2 = TeclaColor(hex: 0x000000, alpha: 0.3)
        static let seg = TeclaColor(hex: 0x45454E, alpha: 1.0)
        static let segT = TeclaColor(hex: 0xFFFFFF, alpha: 1.0)
        static let hover = TeclaColor(hex: 0xFFFFFF, alpha: 0.05)
        static let hover2 = TeclaColor(hex: 0xFFFFFF, alpha: 0.09)
        static let hl = TeclaColor(hex: 0xFFBE0B, alpha: 0.24)
        static let cb = TeclaColor(hex: 0x8F8D9A, alpha: 1.0)
        static let lvOff = TeclaColor(hex: 0xFFFFFF, alpha: 0.18)
        static let card = TeclaColor(hex: 0xFFFFFF, alpha: 0.05)
        static let `in` = TeclaColor(hex: 0x000000, alpha: 0.28)
        static let div = TeclaColor(hex: 0xFFFFFF, alpha: 0.09)
        static let dash = TeclaColor(hex: 0xFFFFFF, alpha: 0.2)
        static let undo = TeclaColor(hex: 0x38383F, alpha: 1.0)
        static let toastBg = TeclaColor(hex: 0x2C2C31, alpha: 1.0)
        static let high = TeclaColor(hex: 0xFF4D5E, alpha: 1.0)
        static let medium = TeclaColor(hex: 0xFF9A1F, alpha: 1.0)
        static let low = TeclaColor(hex: 0x8F8D9A, alpha: 1.0)
        static let lateT = TeclaColor(hex: 0xFF7C89, alpha: 1.0)
        static let lateBg = TeclaColor(hex: 0xFF4D5E, alpha: 0.17)
        static let soonT = TeclaColor(hex: 0xFFB14D, alpha: 1.0)
        static let soonBg = TeclaColor(hex: 0xFF9A1F, alpha: 0.16)
        static let laterT = TeclaColor(hex: 0xC8C6D1, alpha: 1.0)
        static let laterBg = TeclaColor(hex: 0xFFFFFF, alpha: 0.08)
        static let done = TeclaColor(hex: 0xB996FF, alpha: 1.0)
        static let doneBg = TeclaColor(hex: 0x8338EC, alpha: 0.17)
        static let doneLine = TeclaColor(hex: 0x8338EC, alpha: 0.6)
        static let doneTitle = TeclaColor(hex: 0xEFE6FF, alpha: 1.0)
        static let doneText = TeclaColor(hex: 0xC3A4FF, alpha: 1.0)
        static let doneFill = TeclaColor(hex: 0x8338EC, alpha: 1.0)
        static let onDone = TeclaColor(hex: 0xFFFFFF, alpha: 1.0)
        static let key = TeclaColor(hex: 0x3D3D45, alpha: 1.0)
        static let keySide = TeclaColor(hex: 0x0C0C0E, alpha: 1.0)
        static let accentSide = TeclaColor(hex: 0x4F1AA8, alpha: 1.0)
        static let titleUnderline = TeclaColor(hex: 0xFFFFFF, alpha: 0.55)
        static let pressTint = TeclaColor(hex: 0xFFFFFF, alpha: 0.09)
    }

    enum Fonts {
        static let display = TeclaFontFamily(family: "Gabarito", weights: [700, 800], width: nil, file: "Gabarito[wght].ttf")
        static let text = TeclaFontFamily(family: "Onest", weights: [400, 500, 600, 700], width: nil, file: "Onest[wght].ttf")
        static let mono = TeclaFontFamily(family: "Martian Mono", weights: [400, 500, 700], width: 112.5, file: "MartianMono[wdth,wght].ttf")
        static let all = [display, text, mono]
    }

    enum TextStyles {
        static let display = TeclaTextStyle(size: 72, lineHeight: 0.95, trackingEm: -0.035, weight: 800, family: Fonts.display)
        static let title = TeclaTextStyle(size: 44, lineHeight: 1.05, trackingEm: -0.03, weight: 800, family: Fonts.display)
        static let heading = TeclaTextStyle(size: 28, lineHeight: 1.15, trackingEm: -0.02, weight: 700, family: Fonts.display)
        static let subhead = TeclaTextStyle(size: 20, lineHeight: 1.3, trackingEm: -0.01, weight: 700, family: Fonts.display)
        static let body = TeclaTextStyle(size: 16, lineHeight: 1.55, trackingEm: 0.0, weight: 400, family: Fonts.text)
        static let small = TeclaTextStyle(size: 14, lineHeight: 1.5, trackingEm: 0.005, weight: 400, family: Fonts.text)
        static let panelTitle = TeclaTextStyle(size: 16, lineHeight: 1.25, trackingEm: 0.0, weight: 700, family: Fonts.text)
        static let panel = TeclaTextStyle(size: 13, lineHeight: 1.35, trackingEm: 0.0, weight: 400, family: Fonts.text)
        static let panelLabel = TeclaTextStyle(size: 12, lineHeight: 1.35, trackingEm: 0.0, weight: 400, family: Fonts.text)
        static let panelMeta = TeclaTextStyle(size: 11, lineHeight: 1.35, trackingEm: 0.0, weight: 400, family: Fonts.text)
        static let panelChip = TeclaTextStyle(size: 11, lineHeight: 1.35, trackingEm: 0.0, weight: 600, family: Fonts.text)
        static let panelCapture = TeclaTextStyle(size: 14, lineHeight: 1.0, trackingEm: 0.0, weight: 400, family: Fonts.text)
        static let code = TeclaTextStyle(size: 13, lineHeight: 1.6, trackingEm: 0.0, weight: 400, family: Fonts.mono)
    }

    enum Space {
        static let s1: CGFloat = 4
        static let s2: CGFloat = 8
        static let s3: CGFloat = 16
        static let s4: CGFloat = 24
        static let s5: CGFloat = 32
        static let s6: CGFloat = 48
        static let s7: CGFloat = 64
        static let s8: CGFloat = 96
    }

    enum Radius {
        static let small: CGFloat = 8
        static let control: CGFloat = 10
        static let card: CGFloat = 20
        static let panel: CGFloat = 16
        static let row: CGFloat = 9
        static let chip: CGFloat = 6
        static let panelControl: CGFloat = 8
        static let checkbox: CGFloat = 5
        static let bar: CGFloat = 11
        static let input: CGFloat = 8
        static let track: CGFloat = 10
        static let segment: CGFloat = 8
        static let toast: CGFloat = 16
        static let ghost: CGFloat = 6
        static let remove: CGFloat = 5
    }

    enum Size {
        static let levelBarWidth: CGFloat = 4
        static let levelBarRadius: CGFloat = 1.5
        static let levelBarGap: CGFloat = 1.5
        static let checkboxLine: CGFloat = 1.5
        static let undoLine: CGFloat = 2
    }

    enum Key {
        static let sideHeight: CGFloat = 4.0
        static let travel: CGFloat = 3.0
        static let pressScale: CGFloat = 0.99
        static let controlPressScale: CGFloat = 0.97
        static let bigSideHeight: CGFloat = 8.0
        static let bigTravel: CGFloat = 6.0
        static let panelSideHeight: CGFloat = 2.0
        static let panelTravel: CGFloat = 2.0
        static let face = TeclaColor(hex: 0x3D3D45, alpha: 1.0)
        static let side = TeclaColor(hex: 0x0C0C0E, alpha: 1.0)
        static let accentFace = TeclaColor(hex: 0x8338EC, alpha: 1.0)
        static let accentSide = TeclaColor(hex: 0x4F1AA8, alpha: 1.0)
        static let selectedFace = TeclaColor(hex: 0x45454E, alpha: 1.0)
    }

    enum Shadows {
        static let key = [TeclaShadow(x: 0, y: 4, blur: 0, color: TeclaColor(hex: 0x0C0C0E, alpha: 1.0))]
        static let panelKey = [TeclaShadow(x: 0, y: 2, blur: 0, color: TeclaColor(hex: 0x0C0C0E, alpha: 1.0))]
        static let panelAccentKey = [TeclaShadow(x: 0, y: 2, blur: 0, color: TeclaColor(hex: 0x4F1AA8, alpha: 1.0))]
        static let panel = [TeclaShadow(x: 0, y: 6, blur: 0, color: TeclaColor(hex: 0x0C0C0E, alpha: 1.0)), TeclaShadow(x: 0, y: 22, blur: 50, color: TeclaColor(hex: 0x000000, alpha: 0.5))]
        static let alert = [TeclaShadow(x: 0, y: 14, blur: 40, color: TeclaColor(hex: 0x000000, alpha: 0.45))]
    }

    enum Durations {
        static let press: Double = 0.1
        static let key: Double = 0.08
        static let fast: Double = 0.18
        static let base: Double = 0.22
        static let slow: Double = 0.32
        static let panelOpen: Double = 0.2
        static let alert: Double = 0.35
        static let highlight: Double = 1.4
        static let undo: Double = 5.0
    }

    enum Easings {
        static let out = TeclaEasing(x1: 0.2, y1: 0.8, x2: 0.2, y2: 1.0, duration: 0.22)
        static let `in` = TeclaEasing(x1: 0.8, y1: 0.2, x2: 0.8, y2: 0.2, duration: 0.22)
        static let press = TeclaEasing(x1: 0.0, y1: 0.0, x2: 0.58, y2: 1.0, duration: 0.08)
    }

    enum Springs {
        static let `default` = TeclaSpring(response: 0.22, dampingFraction: 1.0)
        static let momentum = TeclaSpring(response: 0.45, dampingFraction: 0.72)
        static let press = TeclaSpring(response: 0.1, dampingFraction: 1.0)
    }
}
