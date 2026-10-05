/// `GET /notices` 항목. 목록에는 본문이 없다.
nonisolated struct NoticeListItemResponseDTO: Decodable, Sendable {
    let noticeId: Int64
    let title: String
    let createdAt: String
}

/// `GET /notices/{id}`.
nonisolated struct NoticeDetailResponseDTO: Decodable, Sendable {
    let noticeId: Int64
    let title: String
    let content: String
    let createdAt: String
    let previousNoticeId: Int64?
    let nextNoticeId: Int64?
}
