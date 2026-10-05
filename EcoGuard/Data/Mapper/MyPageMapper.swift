enum MyPageMapper {
    /// 이름은 로그인 때 저장한 사용자 요약에서, 학년·반은 내 정보 API가 없어 nil.
    /// 환경지킴이 = 구역을 배정받았거나 신청이 승인됨(배정 대기).
    static func summary(
        user: CurrentUser?,
        activity: MyActivityResponseDTO,
        assignment: HomeDTO.Assignment?,
        application: HomeDTO.Application?
    ) -> MyPageSummary {
        MyPageSummary(
            profile: UserProfile(
                // 저장한 사용자 요약이 없으면(이 기능 전에 로그인해 둔 세션) 다시 로그인할 때까지 비워 둔다.
                name: user?.name ?? "",
                grade: nil,
                classNumber: nil,
                isGuardian: assignment != nil || application?.status == .approved
            ),
            monthlyApprovedCount: activity.summary.approvedCount,
            monthlyActivityMinutes: activity.monthlyMinutes,
            cleaningAreaName: assignment?.areaName,
            hasApplied: application != nil
        )
    }
}
