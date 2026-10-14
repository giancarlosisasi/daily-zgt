import Foundation
import Testing
@testable import DailyZGT

@Suite
struct LocalTimeTests {
    static let lima = TimeZone(identifier: "America/Lima") ?? .gmt
    static let tokyo = TimeZone(identifier: "Asia/Tokyo") ?? .gmt

    static func limaDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = lima
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return calendar.date(from: components) ?? .distantPast
    }

    @Test
    func writesTheTimeOfTheZoneAndNotUTC() {
        let date = Self.limaDate(2026, 10, 12, 16)
        #expect(LocalTime.text(from: date, in: Self.lima) == "2026-10-12T16:00:00")
        #expect(LocalTime.text(from: date, in: .gmt) == "2026-10-12T21:00:00")
        #expect(LocalTime.text(from: date, in: Self.tokyo) == "2026-10-13T06:00:00")
    }

    @Test
    func readsTheTextBackToTheSameDate() {
        let date = Self.limaDate(2026, 10, 12, 16)
        #expect(LocalTime.date(from: "2026-10-12T16:00:00", in: Self.lima) == date)
        #expect(LocalTime.date(from: LocalTime.text(from: date)) == date)
        #expect(LocalTime.date(from: "not a date") == nil)
    }

    @Test
    func truncatesToTheSecond() {
        let date = Self.limaDate(2026, 10, 12, 16)
        #expect(LocalTime.truncated(date.addingTimeInterval(0.75)) == date)
    }

    @Test
    func makesTheDayKey() {
        #expect(LocalTime.dayKey(for: Self.limaDate(2026, 10, 12, 23, 30), in: Self.lima) == "2026-10-12")
        #expect(LocalTime.dayKey(for: Self.limaDate(2026, 10, 12, 23, 30), in: Self.tokyo) == "2026-10-13")
    }

    @Test(arguments: [
        ("2026-10-12", "2026-W42"),
        ("2026-10-18", "2026-W42"),
        ("2026-10-19", "2026-W43"),
        ("2026-01-01", "2026-W01"),
        ("2027-01-01", "2026-W53"),
    ])
    func makesTheISOWeekKey(day: String, key: String) throws {
        let date = try #require(LocalTime.date(from: "\(day)T12:00:00", in: Self.lima))
        #expect(LocalTime.weekKey(for: date, in: Self.lima) == key)
    }
}
