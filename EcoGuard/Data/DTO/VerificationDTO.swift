/// 서버 `VerificationStatus`.
nonisolated enum VerificationStatusDTO: String, Decodable, Sendable {
    case processing = "PROCESSING"
    case approved = "APPROVED"
    case rejected = "REJECTED"
    case manualReview = "MANUAL_REVIEW"
}

nonisolated struct SubmitVerificationResponseDTO: Decodable, Sendable {
    let verificationId: Int64
    let status: VerificationStatusDTO
    /// `yyyy-MM-dd'T'HH:mm:ss(.SSSSSS)`(KST). 같은 재전송 키로 다시 보냈으면 처음 접수 시각이다.
    let submittedAt: String
}

/// `POST /verifications` 실패 바디. `ALREADY_SUBMITTED_TODAY`일 때만 `submittedAt`(이미 접수된 인증의 제출 시각)이 있다.
nonisolated struct SubmitVerificationErrorDTO: Decodable, Sendable {
    let code: String
    let submittedAt: String?
}

/// `GET /verifications/today`. 인증 화면 진입용.
nonisolated struct TodayVerificationResponseDTO: Decodable, Sendable {
    /// 서버 지금 시각 `yyyy-MM-dd'T'HH:mm:ss(.SSSSSS)`(KST). 기기 시계 대신 이 시각으로 마감을 계산한다.
    let serverTime: String
    let areaId: Int64
    let areaName: String
    /// 인증 시간 `HH:mm:ss`. 구역에 값이 없으면 서버 기본값(07:20~08:10)이다.
    let startTime: String
    let endTime: String
    let canSubmit: Bool
    /// `canSubmit`이 false일 때만 있다. `ALREADY_SUBMITTED`·`WEEKEND`·`VACATION`·`BEFORE_START`·`AFTER_END`.
    /// 앱이 모르는 값이 와도 화면을 띄우도록 문자열로 받는다.
    let unavailableReason: String?
    let submitted: Bool
    let verificationId: Int64?
    /// 앱이 모르는 값이 와도 화면을 띄우도록 문자열로 받는다.
    let status: String?
    let submittedAt: String?
}

nonisolated struct MyVerificationResponseDTO: Decodable, Sendable {
    let verificationId: Int64
    /// 서버 기준 경로(`/files/verifications/…`). 인증 없이 받을 수 있다.
    let photoUrl: String
    /// `yyyy-MM-dd`(KST).
    let date: String
    /// `yyyy-MM-dd'T'HH:mm:ss(.SSSSSS)`(KST).
    let submittedAt: String
    let areaName: String
    let reviewStatus: VerificationStatusDTO
    /// 반려일 때만 있다.
    let failReasons: [String]?
}

nonisolated struct ReviewResultResponseDTO: Decodable, Sendable {
    let status: VerificationStatusDTO
    /// 반려일 때만 있다.
    let failReasons: [String]?
}
