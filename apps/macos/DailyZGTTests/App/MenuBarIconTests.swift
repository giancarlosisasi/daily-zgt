import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct MenuBarIconTests {
    @Test
    func iconIsASixteenPointTemplateImage() {
        let image = MenuBarIcon.makeImage()
        #expect(image.isTemplate)
        #expect(image.size == NSSize(width: 16, height: 16))
    }

    @Test
    func rendersTheIconAtALargeScale() throws {
        let icon = Image(nsImage: MenuBarIcon.makeImage())
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(Color(white: 0.96))
            .frame(width: 160, height: 160)
            .padding(20)
            .background(Color(white: 0.12))
        let url = try Screenshot.write(icon, named: "menu-bar-icon")
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }
}
