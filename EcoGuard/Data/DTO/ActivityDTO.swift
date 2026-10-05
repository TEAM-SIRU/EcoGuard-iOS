/// 서버 계약: EcoGuard-Server `activity/dto/ActivityDtos.kt`.
nonisolated enum ActivityResultDTO: Decodable, Sendable, Equatable {
    case approved
    case rejected
    case processing
    case manualReview
    /// 인증 시간이 지났는데 제출하지 않은 날.
    case notSubmitted
    /// 아직 인증 시간이 지나지 않은 날.
    case upcoming
    case unknown

    init(from decoder: Decoder) throws {
        switch try decoder.singleValueContainer().decode(String.self) {
        case "APPROVED": self = .approved
        case "REJECTED": self = .rejected
        case "PROCESSING": self = .processing
        case "MANUAL_REVIEW": self = .manualReview
        case "NOT_SUBMITTED": self = .notSubmitted
        case "UPCOMING": self = .upcoming
        default: self = .unknown
        }
    }
}

nonisolated struct ActivityRecordDTO: Decodable, Sendable {
    /// `2026-09-29`
    let date: String
    let area: String?
    let result: ActivityResultDTO
    let verificationId: Int64?
    let photoUrl: String?
    let minutes: Int
}

nonisolated struct ActivitySummaryDTO: Decodable, Sendable {
    let completedDays: Int
    let requiredDays: Int
    let approvedCount: Int
    let rejectedCount: Int
    let notSubmittedCount: Int
}

/// `GET /service-times/me`. 기록은 최신순이고 UPCOMING은 빠져 있다.
nonisolated struct MyActivityResponseDTO: Decodable, Sendable {
    /// 전체 누적 봉사 시간(분).
    let totalMinutes: Int64
    let year: Int
    let month: Int
    let monthlyMinutes: Int
    let summary: ActivitySummaryDTO
    let records: [ActivityRecordDTO]
}

nonisolated struct WeeklyDayDTO: Decodable, Sendable {
    let date: String
    let result: ActivityResultDTO
}

/// `GET /service-times/me/weekly`. `days`는 배정 이후의 평일만 있다(배정 전 요일은 빠진다).
nonisolated struct WeeklyActivityResponseDTO: Decodable, Sendable {
    /// 이번 주 월요일.
    let weekStart: String
    let weekEnd: String
    let completedDays: Int
    let requiredDays: Int
    let days: [WeeklyDayDTO]
}
