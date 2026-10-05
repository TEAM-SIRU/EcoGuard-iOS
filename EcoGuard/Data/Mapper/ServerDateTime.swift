import Foundation

/// 서버 `LocalDateTime` 문자열. 시간대 없이 학교 시간(KST)으로 내려온다.
/// Jackson은 초가 0이면 초를, 나노초가 0이면 소수 초를 뺄 수 있어 `2026-09-01T09:00`, `2026-09-01T09:00:00.123456`을 모두 받는다.
nonisolated enum ServerDateTime {
    static let timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current

    static func date(from string: String) throws -> Date {
        let pattern = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,9}))?)?$/
        guard let match = string.wholeMatch(of: pattern) else { throw APIError.decoding }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(
            year: Int(match.1),
            month: Int(match.2),
            day: Int(match.3),
            hour: Int(match.4),
            minute: Int(match.5),
            second: match.6.flatMap { Int($0) } ?? 0
        )
        guard let date = calendar.date(from: components) else { throw APIError.decoding }
        let fraction = match.7.flatMap { Double("0.\($0)") } ?? 0
        return date.addingTimeInterval(fraction)
    }

    /// "07:20~08:10" → 하루 기준 분. 형식이 다르면 nil.
    static func minuteRange(from string: String) -> (start: Int, end: Int)? {
        let pattern = /^\s*(\d{1,2}):(\d{2})\s*[~\-–]\s*(\d{1,2}):(\d{2})\s*$/
        guard let match = string.wholeMatch(of: pattern),
              let startHour = Int(match.1), let startMinute = Int(match.2),
              let endHour = Int(match.3), let endMinute = Int(match.4)
        else { return nil }
        return (startHour * 60 + startMinute, endHour * 60 + endMinute)
    }
}
