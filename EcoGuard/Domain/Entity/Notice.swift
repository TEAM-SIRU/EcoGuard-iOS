import Foundation

struct Notice: Equatable, Identifiable {
    let id: String
    let title: String
    /// 강조할 부분은 `**`로 감싼 마크다운이다. 목록에서 받은 공지는 본문이 없어 미리보기와 같거나 비어 있다.
    let body: String
    /// 본문 앞부분(서버가 공백을 정리해 최대 100자로 자른다). 목록 표시는 디자인 대기.
    let preview: String
    let publishedAt: Date
    /// 상세를 열어 본 공지인지(서버가 사용자별로 기록한다).
    let isRead: Bool

    /// NEW 표시. 아직 열어 보지 않은 공지다.
    var isNew: Bool { !isRead }
}
