import Foundation

/// 서버 모집 학기 `"2026-2"`(연도-학기). 교사 웹이 이 형식으로 등록한다(서버 README `POST /recruitments`).
nonisolated enum ServerSemester {
    /// 학기 번호(1·2). 형식이 다르면 화면을 실패로 두지 않고 `fallbackDate`(KST)의 학기(3~8월 1학기, 그 밖 2학기)로 둔다.
    static func number(_ semester: String, fallbackDate: Date) -> Int {
        if let match = semester.wholeMatch(of: /\s*\d{4}-([12])\s*/), let number = Int(match.1) {
            return number
        }
        let month = HomeMapper.calendar.component(.month, from: fallbackDate)
        return (3...8).contains(month) ? 1 : 2
    }
}
