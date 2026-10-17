import AppKit
import Foundation
import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct KeyStyleTests {
    @Test
    func aKeyAtRestIsUpWithItsSide() {
        let press = KeyPress.up

        #expect(press.offset == 0)
        #expect(press.sideHeight == Theme.Key.sideHeight)
        #expect(!press.showsPressedTint)
    }

    @Test
    func aPressedKeyMovesDownByItsTravel() {
        let press = KeyPress(isPressed: true)

        #expect(press.offset == Theme.Key.travel)
        #expect(press.offset == TeclaTokens.Key.panelTravel)
        #expect(press.sideHeight == 0)
        #expect(press.animation != nil)
    }

    @Test
    func aPressedKeyDoesNotMoveWithReduceMotion() {
        let press = KeyPress(isPressed: true, reduceMotion: true)

        #expect(press.offset == 0)
        #expect(press.sideHeight == Theme.Key.sideHeight)
        #expect(press.showsPressedTint)
        #expect(press.animation == nil)
    }

    @Test
    func aCheckedCheckboxStaysDown() {
        #expect(KeyPress(staysDown: true).offset == Theme.Key.travel)
        #expect(KeyPress(staysDown: true, reduceMotion: true).offset == Theme.Key.travel)
        #expect(!KeyPress(staysDown: true, reduceMotion: true).showsPressedTint)
    }

    @Test
    func eachRoleHasItsFaceAndItsSide() {
        #expect(KeyRole.primary.face == Theme.Key.accentFace)
        #expect(KeyRole.primary.side == Theme.Key.accentSide)
        #expect(KeyRole.primary.text == Theme.Key.accentText)
        #expect(KeyRole.graphite.face == Theme.Key.face)
        #expect(KeyRole.graphite.side == Theme.Key.side)
        #expect(Theme.Key.sideHeight == TeclaTokens.Key.panelSideHeight)
    }

    @Test
    func eachIconIsInTheAppBundle() {
        for icon in Icon.allCases {
            #expect(NSImage(named: icon.rawValue) != nil, "\(icon.rawValue)")
        }
        #expect(Bundle.main.url(forResource: "Phosphor-LICENSE", withExtension: "txt") != nil)
    }

    private func key(_ title: String, role: KeyRole, pressed: Bool) -> some View {
        Button(action: {}) {
            Text(title)
                .font(Theme.Font.labelStrong)
                .padding(.horizontal, Theme.Confirm.buttonPadding)
                .frame(height: Theme.Key.height)
        }
        .buttonStyle(KeyButtonStyle(role: role, showsPressed: pressed))
    }

    @Test
    func rendersTheKeysUpAndDown() throws {
        let view = VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                key("Añadir", role: .primary, pressed: false)
                key("Añadir", role: .primary, pressed: true)
                key("Cancelar", role: .graphite, pressed: false)
                key("Cancelar", role: .graphite, pressed: true)
            }
            HStack(spacing: 8) {
                PriorityCheckbox(isChecked: false, action: {})
                PriorityCheckbox(isChecked: false, showsPressed: true, action: {})
                PriorityCheckbox(isChecked: true, action: {})
                PriorityCheckbox(isChecked: false, size: Theme.SubtaskList.checkboxSize, action: {})
                PriorityCheckbox(isChecked: true, size: Theme.SubtaskList.checkboxSize, action: {})
                ForEach(Icon.allCases, id: \.self) { icon in
                    IconView(icon: icon, size: 14)
                        .foregroundStyle(Theme.Text.muted)
                }
            }
        }
        let url = try Screenshot.writeHosted(view.panelChrome(), named: "keys")
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }
}
