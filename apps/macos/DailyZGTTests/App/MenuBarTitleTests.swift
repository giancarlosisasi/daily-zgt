import AppKit
import Foundation
import SwiftUI
import Testing
@testable import DailyZGT

@Suite
struct MenuBarTitleCutTests {
    private func letters(_ count: Int) -> String {
        String(repeating: "a", count: count)
    }

    @Test
    func aTitleOf23CharactersStaysWhole() {
        #expect(MenuBarTitle.text(for: letters(23)) == letters(23))
    }

    @Test
    func aTitleOf24CharactersStaysWhole() {
        #expect(MenuBarTitle.text(for: letters(24)) == letters(24))
    }

    @Test
    func aTitleOf25CharactersIsCutToTwentyFourWithTheEllipsisLast() throws {
        let text = try #require(MenuBarTitle.text(for: letters(25)))
        #expect(text == letters(23) + "…")
        #expect(text.count == MenuBarTitle.maxLength)
        #expect(text.last == "…")
    }

    @Test
    func aVeryLongTitleIsCutToTwentyFourCharacters() throws {
        let text = try #require(MenuBarTitle.text(for: letters(200)))
        #expect(text.count == MenuBarTitle.maxLength)
        #expect(text.hasSuffix("…"))
    }

    @Test
    func anEmojiAtTheBoundaryIsNotCutInHalf() throws {
        let family = "👨‍👩‍👧‍👦"
        let text = try #require(MenuBarTitle.text(for: letters(22) + family + letters(5)))
        #expect(text == letters(22) + family + "…")
        #expect(text.count == MenuBarTitle.maxLength)
    }

    @Test
    func anEmojiThatEndsAtTwentyFourCharactersStaysWhole() {
        let family = "👨‍👩‍👧‍👦"
        let title = letters(23) + family
        #expect(MenuBarTitle.text(for: title) == title)
    }

    @Test
    func anAccentIsNotCutFromItsLetter() throws {
        let accented = "e\u{301}"
        let text = try #require(MenuBarTitle.text(for: letters(22) + accented + letters(4)))
        #expect(text == letters(22) + accented + "…")
        #expect(text.count == MenuBarTitle.maxLength)
    }

    @Test
    func spacesBeforeTheEllipsisGoAway() throws {
        let text = try #require(MenuBarTitle.text(for: letters(20) + "   " + letters(10)))
        #expect(text == letters(20) + "…")
    }

    @Test
    func spacesAtTheEdgesGoAway() {
        #expect(MenuBarTitle.text(for: "   Pagar la luz  ") == "Pagar la luz")
    }

    @Test
    func aNewlineBecomesASpace() {
        #expect(MenuBarTitle.text(for: "Pagar\nla luz") == "Pagar la luz")
    }

    @Test
    func noTitleGivesNoText() {
        #expect(MenuBarTitle.text(for: nil) == nil)
        #expect(MenuBarTitle.text(for: "") == nil)
        #expect(MenuBarTitle.text(for: "   ") == nil)
    }
}

@Suite
@MainActor
struct MenuBarTitleStoreTests {
    let clock = TestClock("2026-10-12T10:24:00")

    private func readyBoot(_ store: AppStore) -> AppBoot {
        .ready(
            store,
            PanelState(store: store),
            AlertCoordinator(store: store, center: InertNotificationCenter()),
            CaptureController(store: store)
        )
    }

    @Test
    func aFailedBootHasNoTitle() {
        #expect(AppBoot.failed.menuBarTitle == nil)
    }

    @Test
    func anEmptyListHasNoTitle() throws {
        let store = try makeStore(clock)
        #expect(readyBoot(store).menuBarTitle == nil)
    }

    @Test
    func theTitleIsTheFirstOpenPriorityOfTodayInTheStoreOrder() throws {
        let store = try makeStore(clock)
        try store.addPriority(title: "Low", level: .low, list: .today)
        try store.addPriority(title: "Medium late", level: .medium, list: .today, dueAt: localDate("2026-10-12T18:00:00"))
        try store.addPriority(title: "Medium soon", level: .medium, list: .today, dueAt: localDate("2026-10-12T12:00:00"))
        try store.addPriority(title: "High", level: .high, list: .today)
        try store.addPriority(title: "Week high", level: .high, list: .week)
        #expect(readyBoot(store).menuBarTitle == "High")
    }

    @Test
    func theDueBreaksATieOfLevel() throws {
        let store = try makeStore(clock)
        try store.addPriority(title: "No due", list: .today)
        try store.addPriority(title: "Late", list: .today, dueAt: localDate("2026-10-12T18:00:00"))
        try store.addPriority(title: "Soon", list: .today, dueAt: localDate("2026-10-12T12:00:00"))
        #expect(readyBoot(store).menuBarTitle == "Soon")
    }

    @Test
    func theCreationOrderBreaksATieOfLevelAndDue() throws {
        let store = try makeStore(clock)
        try store.addPriority(title: "First", list: .today)
        try store.addPriority(title: "Second", list: .today)
        #expect(readyBoot(store).menuBarTitle == "First")
    }

    @Test
    func aDonePriorityDoesNotShow() throws {
        let store = try makeStore(clock)
        let only = try store.addPriority(title: "Only", list: .today)
        try store.markDone(only.id)
        #expect(readyBoot(store).menuBarTitle == nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func theTitleFollowsEveryStoreChange() async throws {
        let store = try makeStore(clock)
        let boot = readyBoot(store)
        #expect(boot.menuBarTitle == nil)

        var first: Priority?
        try await nextChange(of: store) { first = try store.addPriority(title: "First", level: .medium, list: .today) }
        let one = try #require(first)
        #expect(boot.menuBarTitle == "First")

        var second: Priority?
        try await nextChange(of: store) { second = try store.addPriority(title: "Second", level: .high, list: .today) }
        let two = try #require(second)
        #expect(boot.menuBarTitle == "Second")

        try await nextChange(of: store) { try store.markDone(two.id) }
        #expect(boot.menuBarTitle == "First")

        try await nextChange(of: store) { try store.restorePriority(two.id) }
        #expect(boot.menuBarTitle == "Second")

        try await nextChange(of: store) { try store.editPriority(two.id) { $0.title = "Second edited" } }
        #expect(boot.menuBarTitle == "Second edited")

        try await nextChange(of: store) { try store.editPriority(two.id) { $0.level = .low } }
        #expect(boot.menuBarTitle == "First")

        try await nextChange(of: store) {
            try store.editPriority(two.id) {
                $0.level = .medium
                $0.dueAt = localDate("2026-10-12T11:00:00")
            }
        }
        #expect(boot.menuBarTitle == "Second edited")

        try await nextChange(of: store) { try store.movePriority(two.id, to: .week) }
        #expect(boot.menuBarTitle == "First")

        try await nextChange(of: store) { try store.movePriority(two.id, to: .today) }
        #expect(boot.menuBarTitle == "Second edited")

        try await nextChange(of: store) { try store.deletePriority(two.id) }
        #expect(boot.menuBarTitle == "First")

        try await nextChange(of: store) { try store.deletePriority(one.id) }
        #expect(boot.menuBarTitle == nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func aDailyCopyShowsItsTitle() async throws {
        let store = try makeStore(clock)
        let source = try addDaily(store, title: "Meditar")
        try store.markDone(source.id)
        clock.date = localDate("2026-10-13T07:00:00")
        let boot = readyBoot(store)
        #expect(boot.menuBarTitle == nil)

        try await nextChange(of: store) { try store.addRepeatCopies() }
        #expect(boot.menuBarTitle == "Meditar")
    }

    @Test(.timeLimit(.minutes(1)))
    func theTitleFollowsAWriteFromTheSqlite3Tool() async throws {
        let folder = try temporaryFolder("menu-bar-title-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "daily-zgt.sqlite")
        let store = AppStore(database: try AppDatabase.onDisk(at: url))
        let boot = readyBoot(store)
        #expect(boot.menuBarTitle == nil)

        try await nextChange(of: store) {
            let tool = Process()
            tool.executableURL = URL(filePath: "/usr/bin/sqlite3")
            tool.arguments = [url.path, AppStoreObservationTests.insertPriority]
            try tool.run()
            tool.waitUntilExit()
            #expect(tool.terminationStatus == 0)
        }
        #expect(boot.menuBarTitle != nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func theLabelDependsOnTheTitleSoSwiftUIRedrawsIt() async throws {
        let store = try makeStore(clock)
        let boot = readyBoot(store)
        let (changes, continuation) = AsyncStream.makeStream(of: Void.self)
        withObservationTracking {
            _ = boot.menuBarTitle
        } onChange: {
            continuation.yield()
        }

        try store.addPriority(title: "Observed", list: .today)

        for await _ in changes {
            break
        }
        #expect(boot.menuBarTitle == "Observed")
    }
}

@Suite
@MainActor
struct MenuBarTitleSettingTests {
    let clock = TestClock("2026-10-12T10:24:00")

    private func readyBoot(_ store: AppStore) -> (AppBoot, PanelState) {
        let state = PanelState(store: store)
        let alerts = AlertCoordinator(store: store, center: InertNotificationCenter())
        return (.ready(store, state, alerts, CaptureController(store: store)), state)
    }

    @Test
    func theSettingIsOnByDefault() throws {
        let store = try makeStore(clock)
        #expect(store.menuBarTitleIsOn)
        #expect(try values("SELECT key FROM app_state", in: store.database, as: String.self).isEmpty)
    }

    @Test
    func turningItOffHidesTheTitleAndTurningItOnShowsItAgain() throws {
        let store = try makeStore(clock)
        try store.addPriority(title: "Pagar la luz", list: .today)
        let (boot, state) = readyBoot(store)
        #expect(boot.menuBarTitle == "Pagar la luz")

        state.setMenuBarTitle(false)
        #expect(!store.menuBarTitleIsOn)
        #expect(boot.menuBarTitle == nil)
        #expect(boot.menuBarCount == 1)

        state.setMenuBarTitle(true)
        #expect(boot.menuBarTitle == "Pagar la luz")
    }

    @Test
    func theSettingLivesInAppState() throws {
        let store = try makeStore(clock)
        let (_, state) = readyBoot(store)
        state.setMenuBarTitle(false)
        #expect(try values("SELECT value FROM app_state WHERE key = 'menu_bar_title'", in: store.database) == ["false"])
        #expect(state.saveError == nil)
    }

    @Test
    func aNewStoreOnTheSameDatabaseKeepsTheSetting() throws {
        let database = try AppDatabase.inMemory()
        PanelState(store: AppStore(database: database)).setMenuBarTitle(false)
        #expect(!AppStore(database: database).menuBarTitleIsOn)
    }

    @Test
    func theSettingSurvivesAFileReopen() throws {
        let url = try temporaryFolder("menu-bar-title-setting").appending(path: "daily-zgt.sqlite")
        PanelState(store: AppStore(database: try AppDatabase.onDisk(at: url))).setMenuBarTitle(false)
        #expect(!AppStore(database: try AppDatabase.onDisk(at: url)).menuBarTitleIsOn)
    }

    @Test(.timeLimit(.minutes(1)))
    func turningTheSettingOffRedrawsTheLabel() async throws {
        let store = try makeStore(clock)
        try store.addPriority(title: "Pagar la luz", list: .today)
        let (boot, state) = readyBoot(store)
        let (changes, continuation) = AsyncStream.makeStream(of: Void.self)
        withObservationTracking {
            _ = boot.menuBarTitle
        } onChange: {
            continuation.yield()
        }

        state.setMenuBarTitle(false)

        for await _ in changes {
            break
        }
        #expect(boot.menuBarTitle == nil)
    }

    @Test
    func theSettingsRowHasTheTitleAndTheLine() {
        #expect(SettingsCopy.menuBarTitleTitle == "Siguiente prioridad en la barra de menús")
        #expect(!SettingsCopy.menuBarTitleDetail.isEmpty)
    }
}

@Suite
@MainActor
struct MenuBarTitleRenderTests {
    private let shortTitle = "Pagar la luz"
    private let longTitle = "Terminar el brief de Tailwind v4 para el equipo"

    private func renderLabel(count: Int?, title: String?, dark: Bool, name: String) throws {
        let label = MenuBarLabel(count: count, title: title)
            .foregroundStyle(dark ? Color(TeclaTokens.Colors.keyT) : Color(TeclaTokens.Colors.mbBg))
            .padding(.horizontal, 7)
            .frame(height: 22)
            .padding(8)
            .background(dark ? Color(TeclaTokens.Colors.mbBg) : Color(TeclaTokens.Colors.keyT))
        let url = try Screenshot.writeHosted(label, named: name)
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }

    @Test
    func rendersTheLabelWithAShortAndALongTitleOnLightAndDark() throws {
        for dark in [false, true] {
            let mode = dark ? "dark" : "light"
            try renderLabel(count: 4, title: shortTitle, dark: dark, name: "menu-bar-title-short-\(mode)")
            try renderLabel(count: 4, title: longTitle, dark: dark, name: "menu-bar-title-long-\(mode)")
        }
        try renderLabel(count: 4, title: nil, dark: true, name: "menu-bar-title-off-dark")
    }

    @Test
    func theWidestLabelFitsInTheMenuBar() {
        let widest = String(repeating: "W", count: 40)
        let width = NSHostingView(rootView: MenuBarLabel(count: 99, title: widest)).fittingSize.width
        print("menu-bar-widest-label-width: \(width)")
        let plain = NSHostingView(rootView: MenuBarLabel(count: 99)).fittingSize.width
        #expect(width > plain)
        #expect(width < 340)
    }

    @Test
    func aLongTitleAddsWidthButNeverMoreThanTheCut() {
        let short = NSHostingView(rootView: MenuBarLabel(count: 4, title: "Hola")).fittingSize.width
        let long = NSHostingView(rootView: MenuBarLabel(count: 4, title: String(repeating: "a", count: 25))).fittingSize.width
        let longer = NSHostingView(rootView: MenuBarLabel(count: 4, title: String(repeating: "a", count: 90))).fittingSize.width
        #expect(long > short)
        #expect(longer == long)
    }
}

@Suite
@MainActor
struct MenuBarTitleSettingsRenderTests {
    @Test
    func rendersTheSettingsWithTheNewRow() throws {
        let clock = TestClock("2026-10-12T10:24:00")
        let store = try makeStore(clock)
        try store.addPriority(title: "Terminar el brief de Tailwind v4", level: .high, list: .today)
        let state = PanelState(
            store: store,
            loginItem: LoginItemSettings(service: FakeLoginItemService(status: .notRegistered), events: NotificationCenter())
        )
        state.openSettings()
        let url = try Screenshot.writeHosted(PanelView().environment(store).environment(state), named: "settings-menu-bar-title")
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }
}
