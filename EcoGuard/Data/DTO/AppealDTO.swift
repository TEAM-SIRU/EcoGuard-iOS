/// 서버 `AppealStatus`.
nonisolated enum AppealStatusDTO: String, Decodable, Sendable {
    case pending = "PENDING"
    case approved = "APPROVED"
    case rejected = "REJECTED"
}

nonisolated struct CreateAppealRequestDTO: Encodable, Sendable {
    let content: String
}

nonisolated struct CreateAppealResponseDTO: Decodable, Sendable {
    let appealId: Int64
    let status: AppealStatusDTO
    let round: Int
}

nonisolated struct MyAppealResponseDTO: Decodable, Sendable {
    let appealId: Int64
    let verificationId: Int64
    let round: Int
    let areaName: String
    /// 대상 인증 날짜 `yyyy-MM-dd`(KST).
    let verificationDate: String
    let content: String
    let status: AppealStatusDTO
    /// 선생님 답변. 반려 사유로 보여 준다.
    let reply: String?
    /// `yyyy-MM-dd'T'HH:mm:ss[.SSSSSS]`(KST, 시간대 표기 없음).
    let createdAt: String
}
