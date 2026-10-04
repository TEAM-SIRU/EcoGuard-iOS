/// 마이페이지(Figma `12 전체`)에 보여 줄 내 정보와 활동 요약.
struct MyPageSummary: Hashable {
    let profile: UserProfile
    /// 이번 달 승인된 청소 인증 횟수.
    let monthlyApprovedCount: Int
    /// 이번 달 인정된 활동 시간(분). 서버가 10분 단위로 쌓은 값을 그대로 쓴다.
    let monthlyActivityMinutes: Int
    /// 배정된 청소 구역 이름. 배정 전이면 nil.
    let cleaningAreaName: String?
    /// 환경지킴이 모집에 신청했는지. 신청하면 바로 확정된다.
    let hasApplied: Bool
}
