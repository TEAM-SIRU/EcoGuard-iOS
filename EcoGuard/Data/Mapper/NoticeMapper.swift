import Foundation

extension NoticeListItemResponseDTO {
    /// 목록에는 본문이 없어 빈 문자열로 둔다. 본문은 상세(`fetchNotice(id:)`)로 받는다.
    func toDomain() throws -> Notice {
        Notice(
            id: String(noticeId),
            title: title,
            body: "",
            preview: preview,
            publishedAt: try ServerDate.requiredDateTime(createdAt),
            isRead: isRead
        )
    }
}

extension NoticeDetailResponseDTO {
    /// 상세를 받으면 서버가 읽음으로 기록하므로 읽은 공지다. 미리보기는 서버와 같은 규칙(공백 정리 후 100자)으로 만든다.
    func toDomain() throws -> Notice {
        Notice(
            id: String(noticeId),
            title: title,
            body: content,
            preview: String(content.split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(100)),
            publishedAt: try ServerDate.requiredDateTime(createdAt),
            isRead: true
        )
    }
}
