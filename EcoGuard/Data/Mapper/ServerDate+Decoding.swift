import Foundation

nonisolated extension ServerDate {
    /// 읽을 수 없으면 디코딩 실패로 본다.
    static func requiredDateTime(_ string: String) throws -> Date {
        guard let date = dateTime(string) else { throw APIError.decoding }
        return date
    }

    /// 청소 시간 "07:20~08:10" → 하루 기준 분. 형식이 다르면 nil.
    static func minuteRange(_ string: String) -> (start: Int, end: Int)? {
        let pattern = /^\s*(\d{1,2}):(\d{2})\s*[~\-–]\s*(\d{1,2}):(\d{2})\s*$/
        guard let match = string.wholeMatch(of: pattern),
              let startHour = Int(match.1), let startMinute = Int(match.2),
              let endHour = Int(match.3), let endMinute = Int(match.4)
        else { return nil }
        return (startHour * 60 + startMinute, endHour * 60 + endMinute)
    }
}
