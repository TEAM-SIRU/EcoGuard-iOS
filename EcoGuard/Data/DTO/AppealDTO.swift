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
    /// 이의신청 때 첨부한 사진 주소(서버 `/files/...` 상대 경로일 수 있다).
    let photoUrls: [String]?
    let status: AppealStatusDTO
    /// 승인되어 적립된 분. 승인 전이거나 반려면 null.
    let awardedMinutes: Int?
    /// 선생님 답변 제목(선택).
    let replyTitle: String?
    /// 선생님 답변 본문. 반려 사유로 보여 준다.
    let reply: String?
    /// `yyyy-MM-dd'T'HH:mm:ss[.SSSSSS]`(KST, 시간대 표기 없음).
    let createdAt: String
}
