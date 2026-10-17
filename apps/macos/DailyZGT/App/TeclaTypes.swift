import SwiftUI

struct TeclaColor: Equatable, Sendable {
    let hex: UInt32
    let alpha: Double

    var red: Double { Double((hex >> 16) & 0xFF) / 255 }
    var green: Double { Double((hex >> 8) & 0xFF) / 255 }
    var blue: Double { Double(hex & 0xFF) / 255 }
}

struct TeclaFontFamily: Equatable, Sendable {
    let family: String
    let weights: [Int]
    let width: Double?
    let file: String
}

struct TeclaTextStyle: Equatable, Sendable {
    let size: CGFloat
    let lineHeight: CGFloat
    let trackingEm: CGFloat
    let weight: Int
    let family: TeclaFontFamily
}

struct TeclaShadow: Equatable, Sendable {
    let x: CGFloat
    let y: CGFloat
    let blur: CGFloat
    let color: TeclaColor
}

struct TeclaEasing: Equatable, Sendable {
    let x1: Double
    let y1: Double
    let x2: Double
    let y2: Double
    let duration: Double
}

struct TeclaSpring: Equatable, Sendable {
    let response: Double
    let dampingFraction: Double
}

enum TeclaWeight: Int, CaseIterable, Sendable {
    case regular = 400
    case medium = 500
    case semibold = 600
    case bold = 700
    case extraBold = 800
}

extension Color {
    init(_ token: TeclaColor) {
        self.init(.sRGB, red: token.red, green: token.green, blue: token.blue, opacity: token.alpha)
    }
}

extension Animation {
    static func tecla(_ easing: TeclaEasing) -> Animation {
        .timingCurve(easing.x1, easing.y1, easing.x2, easing.y2, duration: easing.duration)
    }

    static func tecla(_ easing: TeclaEasing, duration: Double) -> Animation {
        .timingCurve(easing.x1, easing.y1, easing.x2, easing.y2, duration: duration)
    }

    static func tecla(_ spring: TeclaSpring) -> Animation {
        .spring(response: spring.response, dampingFraction: spring.dampingFraction)
    }
}

extension Duration {
    static func tecla(_ seconds: Double) -> Duration {
        .milliseconds(Int((seconds * 1000).rounded()))
    }
}
