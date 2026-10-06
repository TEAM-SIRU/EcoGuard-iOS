import Foundation

nonisolated extension ServerDate {
    /// 시간대를 붙인 ISO-8601(`2026-10-05T08:09:58+09:00`). 서버가 `OffsetDateTime.parse`로 읽는 헤더 값에 쓴다.
    static func offsetDateTime(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = .withInternetDateTime
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}
