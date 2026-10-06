/// `GET /notices` 항목. 목록에는 본문 대신 미리보기가 있다.
nonisolated struct NoticeListItemResponseDTO: Decodable, Sendable {
    let noticeId: Int64
    let title: String
    /// 본문 앞부분(공백 정리 후 최대 100자).
    let preview: String
    /// 요청한 사용자가 상세를 이미 열어 봤는지.
    let isRead: Bool
    let createdAt: String
}

/// `GET /notices/{id}`. 받으면 서버가 이 공지를 읽음으로 기록한다.
nonisolated struct NoticeDetailResponseDTO: Decodable, Sendable {
    let noticeId: Int64
    let title: String
    let content: String
    let createdAt: String
    let previousNoticeId: Int64?
    let nextNoticeId: Int64?
}
