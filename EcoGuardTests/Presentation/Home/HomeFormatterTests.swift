import Foundation
import Testing
@testable import EcoGuard

struct HomeFormatterTests {
    private func date(month: Int, day: Int, hour: Int, minute: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
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

    @Test(arguments: [(2, "월"), (3, "화"), (6, "금")])
    func weekdaySymbolIsKorean(weekday: Int, expected: String) {
        #expect(HomeFormatter.weekdaySymbol(weekday) == expected)
    }
}
