/// 모집 기간 중 미가입 학생에게 보여 주는 모집 현황.
struct Recruitment: Equatable {
    /// 서버 학기를 읽을 수 없으면 nil이고 화면은 학기 없이 보여 준다.
    let semester: Int?
    let capacityPerClass: Int
    let className: String
    let appliedCount: Int
}
