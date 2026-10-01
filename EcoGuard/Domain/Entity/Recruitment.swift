/// 모집 기간 중 미가입 학생에게 보여 주는 모집 현황.
struct Recruitment: Equatable {
    let semester: Int
    let capacityPerClass: Int
    let className: String
    let appliedCount: Int
}
