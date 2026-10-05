nonisolated enum MyPageMapper {
    /// 환경지킴이 = 구역을 배정받았거나 신청이 승인됨(배정 대기).
    static func summary(
        activity: MyActivityResponseDTO,
        assignment: HomeDTO.Assignment?,
        application: HomeDTO.Application?
    ) -> MyPageSummary {
        MyPageSummary(
            profile: UserProfile(
                name: nil,
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
