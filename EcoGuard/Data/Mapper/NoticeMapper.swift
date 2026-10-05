import Foundation

extension NoticeListItemResponseDTO {
    /// 목록에는 본문이 없어 빈 문자열로 둔다. 본문은 상세(`fetchNotice(id:)`)로 받는다.
    /// 읽음 정보가 서버에 없어 `isNew`는 false다(서버 요청 목록).
    func toDomain() throws -> Notice {
        Notice(id: String(noticeId), title: title, body: "", publishedAt: try ServerDate.requiredDateTime(createdAt), isNew: false)
    }
}

extension NoticeDetailResponseDTO {
    func toDomain() throws -> Notice {
        Notice(id: String(noticeId), title: title, body: content, publishedAt: try ServerDate.requiredDateTime(createdAt), isNew: false)
    }
}
