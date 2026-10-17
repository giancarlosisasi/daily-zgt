import Foundation
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct AlertsOffNoticeTests {
    @Test
    func theCopyIsOneShortSentenceWithNoSettingsPath() {
        #expect(AlertCopy.off == "Las alertas están desactivadas.")
        #expect(!AlertCopy.off.contains(">"))
        #expect(!AlertCopy.off.contains("Configuración"))
        #expect(AlertCopy.openSettings == "Abrir ajustes")
    }

    @Test
    func theSettingsUrlPointsToTheNotificationsPane() {
        #expect(NotificationSettings.url.absoluteString == "x-apple.systempreferences:com.apple.Notifications-Settings.extension")
    }

    @Test
    func openingTheSettingsPassesTheUrlToTheOpener() {
        var opened: [URL] = []
        let result = NotificationSettings.open(using: { url in
            opened.append(url)
            return true
        })
        #expect(result)
        #expect(opened == [NotificationSettings.url])
    }

    @Test
    func aFailedOpenReturnsFalse() {
        #expect(!NotificationSettings.open(using: { _ in false }))
    }
}
