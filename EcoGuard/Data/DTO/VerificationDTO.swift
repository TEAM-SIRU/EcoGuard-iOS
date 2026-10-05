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
}

nonisolated struct MyVerificationResponseDTO: Decodable, Sendable {
    let verificationId: Int64
    /// 서버 기준 경로(`/files/verifications/…`). 인증 없이 받을 수 있다.
    let photoUrl: String
    /// `yyyy-MM-dd`(KST). 제출 시각은 내려 주지 않는다.
    let date: String
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
