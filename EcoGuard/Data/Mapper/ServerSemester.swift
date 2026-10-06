/// 서버 모집 학기. 교사 웹은 `"2026-2"`(연도-학기)로 등록한다(서버 README `POST /recruitments`).
nonisolated enum ServerSemester {
    /// 학기 번호(1·2). `"2026-2"`를 먼저 보고, 아니면 끝 숫자(`"2"`, `"2학기"`)를 읽는다.
    /// 그래도 읽을 수 없으면 nil이고 화면은 학기 없이 보여 준다(어림한 학기를 단정해 보여 주지 않는다).
    static func number(_ semester: String) -> Int? {
        if let match = semester.wholeMatch(of: /\s*\d{4}-([12])\s*/) {
            return Int(match.1)
        }
        guard let match = semester.firstMatch(of: /(\d+)\D*$/), let number = Int(match.1), (1...2).contains(number) else {
            return nil
        }
        return number
    }
}
