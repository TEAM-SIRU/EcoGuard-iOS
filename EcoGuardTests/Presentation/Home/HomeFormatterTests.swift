import Foundation
import Testing
@testable import EcoGuard

@Suite(.serialized)
struct HomeFormatterTests {
    private func date(month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    @Test func windowFormatsMinutesOfDay() {
        #expect(HomeFormatter.window(CleaningWindow(startMinute: 480, endMinute: 490)) == "08:00 – 08:10")
    }

    @Test(arguments: [
        (TimeInterval(332), "05:32"),
        (332.9, "05:32"),
        (0, "00:00"),
        (-5, "00:00")
    ])
    func countdownClampsAtZero(remaining: TimeInterval, expected: String) {
        #expect(HomeFormatter.countdown(remaining) == expected)
    }

    @Test func recordDateMatchesFigma() {
        #expect(HomeFormatter.recordDate(date(month: 9, day: 28, hour: 8, minute: 5)) == "9월 28일(월) 08:05")
    }

    @Test func noticeDateMatchesFigma() {
        #expect(HomeFormatter.noticeDate(date(month: 9, day: 1, hour: 0, minute: 0)) == "2026. 09. 01")
    }

    @Test(arguments: ["America/New_York", "UTC", "Asia/Seoul"])
    func formatsInKSTRegardlessOfDeviceTimeZone(identifier: String) {
        let original = NSTimeZone.default
        defer { NSTimeZone.default = original }
        NSTimeZone.default = TimeZone(identifier: identifier) ?? original
        // KST 9/29 00:30 = 뉴욕 9/28 11:30. 기기 시간대를 따르면 날짜·요일이 하루 밀린다.
        let date = date(month: 9, day: 29, hour: 0, minute: 30)

        #expect(HomeFormatter.recordDate(date) == "9월 29일(화) 00:30")
        #expect(HomeFormatter.clockTime(date) == "00:30")
        #expect(HomeFormatter.noticeDate(date) == "2026. 09. 29")
    }

    @Test(arguments: [(2, "월"), (3, "화"), (6, "금")])
    func weekdaySymbolIsKorean(weekday: Int, expected: String) {
        #expect(HomeFormatter.weekdaySymbol(weekday) == expected)
    }
}
