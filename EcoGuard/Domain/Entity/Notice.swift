import Foundation

struct Notice: Equatable, Identifiable {
    let id: String
    let title: String
    /// 강조할 부분은 `**`로 감싼 마크다운이다.
    let body: String
    let publishedAt: Date
    let isNew: Bool
}
