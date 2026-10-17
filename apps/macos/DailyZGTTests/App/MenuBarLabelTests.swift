import Observation
import SwiftUI
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct MenuBarLabelTests {
    private func readyBoot(_ store: AppStore) -> AppBoot {
        .ready(
            store,
            PanelState(store: store),
            AlertCoordinator(store: store, center: InertNotificationCenter()),
            CaptureController(store: store)
        )
    }

    @Test
    func theTextIsTheCountForZeroOneAndMany() {
        #expect(MenuBarCount.text(for: 0) == "0")
        #expect(MenuBarCount.text(for: 1) == "1")
        #expect(MenuBarCount.text(for: 12) == "12")
        #expect(MenuBarCount.text(for: 120) == "120")
    }

    @Test
    func aMissingCountHasNoText() {
        #expect(MenuBarCount.text(for: nil) == nil)
    }

    @Test
    func aNegativeCountShowsZero() {
        #expect(MenuBarCount.text(for: -3) == "0")
    }

    @Test
    func aFailedBootHasNoCount() {
        #expect(AppBoot.failed.menuBarCount == nil)
    }

    @Test
    func theCountIsTheOpenPrioritiesOfToday() throws {
        let store = try makeStore()
        try store.addPriority(title: "Today open", list: .today)
        try store.addPriority(title: "Today open too", list: .today)
        try store.addPriority(title: "Week open", list: .week)
        let done = try store.addPriority(title: "Today done", list: .today)
        try store.markDone(done.id)

        #expect(readyBoot(store).menuBarCount == 2)
    }

    @Test(.timeLimit(.minutes(1)))
    func theCountFollowsEveryStoreChange() async throws {
        let store = try makeStore()
        let boot = readyBoot(store)
        #expect(boot.menuBarCount == 0)

        var added: Priority?
        try await nextChange(of: store) { added = try store.addPriority(title: "First", list: .today) }
        #expect(boot.menuBarCount == 1)
        let first = try #require(added)

        try await nextChange(of: store) { try store.addPriority(title: "Second", list: .today) }
        #expect(boot.menuBarCount == 2)

        try await nextChange(of: store) { try store.markDone(first.id) }
        #expect(boot.menuBarCount == 1)

        try await nextChange(of: store) { try store.restorePriority(first.id) }
        #expect(boot.menuBarCount == 2)

        try await nextChange(of: store) { try store.movePriority(first.id, to: .week) }
        #expect(boot.menuBarCount == 1)

        try await nextChange(of: store) { try store.movePriority(first.id, to: .today) }
        #expect(boot.menuBarCount == 2)

        try await nextChange(of: store) { try store.deletePriority(first.id) }
        #expect(boot.menuBarCount == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func theCountFollowsAWriteFromTheSqlite3Tool() async throws {
        let folder = try temporaryFolder("menu-bar-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "daily-zgt.sqlite")
        let store = AppStore(database: try AppDatabase.onDisk(at: url))
        let boot = readyBoot(store)
        #expect(boot.menuBarCount == 0)

        try await nextChange(of: store) {
            let tool = Process()
            tool.executableURL = URL(filePath: "/usr/bin/sqlite3")
            tool.arguments = [url.path, AppStoreObservationTests.insertPriority]
            try tool.run()
            tool.waitUntilExit()
            #expect(tool.terminationStatus == 0)
        }
        #expect(boot.menuBarCount == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func theLabelDependsOnTheCountSoSwiftUIRedrawsIt() async throws {
        let store = try makeStore()
        let boot = readyBoot(store)
        let (changes, continuation) = AsyncStream.makeStream(of: Void.self)
        withObservationTracking {
            _ = boot.menuBarCount
        } onChange: {
            continuation.yield()
        }

        try store.addPriority(title: "Observed", list: .today)

        for await _ in changes {
            break
        }
        #expect(boot.menuBarCount == 1)
    }

    private func renderLabel(count: Int?, dark: Bool, name: String) throws {
        let label = MenuBarLabel(count: count)
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
    func rendersTheLabelForZeroFourAndTwelveOnLightAndDark() throws {
        for count in [0, 4, 12] {
            try renderLabel(count: count, dark: false, name: "menu-bar-label-\(count)-light")
            try renderLabel(count: count, dark: true, name: "menu-bar-label-\(count)-dark")
        }
        try renderLabel(count: nil, dark: true, name: "menu-bar-label-icon-only-dark")
    }
}
