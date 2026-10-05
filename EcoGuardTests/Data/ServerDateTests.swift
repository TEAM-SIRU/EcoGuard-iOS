import Foundation
import Testing
@testable import EcoGuard

struct ServerDateTests {
    private static func kst(_ hour: Int, _ minute: Int, _ second: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar.date(from: DateComponents(year: 2026, month: 9, day: 29, hour: hour, minute: minute, second: second))!
    }

    @Test(arguments: [
        ("2026-09-29T08:04:00", 8, 4, 0),
        ("2026-09-29T08:04:07.123456", 8, 4, 7),
        ("2026-09-29T08:04", 8, 4, 0)
    ])
    func dateTime(raw: String, hour: Int, minute: Int, second: Int) {
        #expect(ServerDate.dateTime(raw) == Self.kst(hour, minute, second))
    }

    @Test func dateIsStartOfDayInSeoul() {
        #expect(ServerDate.date("2026-09-29") == Self.kst(0, 0, 0))
    }

    @Test(arguments: ["2026-09-29", "2026-13-01T00:00:00", "2026-09-29T25:00:00", "abc", "2026-09-29T08:04:00Z"])
    func invalidDateTime(raw: String) {
        #expect(ServerDate.dateTime(raw) == nil)
    }
}
