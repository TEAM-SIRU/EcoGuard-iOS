import Foundation

/// 서버 날짜 문자열. 서버는 시간대 없이 학교 시간대(KST) 기준 `LocalDate`(`2026-09-29`)·`LocalDateTime`(`2026-09-29T08:04:00`)을 내려준다.
nonisolated enum ServerDate {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }()

    /// `2026-09-29` → 그날 0시(KST). 형식이 다르면 nil.
    static func day(_ string: String) -> Date? {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard components.isValidDate(in: calendar) else { return nil }
        return calendar.date(from: components)
    }

    /// `2026-09-29T08:04:00`(소수점 초가 붙어도 된다) → KST 시각. 형식이 다르면 nil.
    static func dateTime(_ string: String) -> Date? {
        let parts = string.split(separator: "T", maxSplits: 1)
        guard parts.count == 2, let day = day(String(parts[0])) else { return nil }
        let time = parts[1].split(separator: ":")
        guard time.count >= 2, let hour = Int(time[0]), let minute = Int(time[1]) else { return nil }
        let second = time.count > 2 ? Double(time[2]) ?? 0 : 0
        return day.addingTimeInterval(TimeInterval(hour * 3600 + minute * 60) + second)
    }
}
