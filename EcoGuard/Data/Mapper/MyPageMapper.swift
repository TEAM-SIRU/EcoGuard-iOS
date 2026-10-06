enum MyPageMapper {
    /// 신청 여부는 홈·신청 결과와 같이 현재 공고에 신청했는지(`alreadyApplied`)로 본다. 지난 모집의 신청으로 판단하지 않는다.
    /// 환경지킴이 = 구역을 배정받았거나, 현재 공고에 한 신청이 미선발(`REJECTED`, 이전 데이터)이 아님(배정 대기).
    /// 내 정보를 받지 못했으면(`user`가 nil) 이름·학반을 비워 둔다.
    static func summary(
        user: CurrentUser?,
        activity: MyActivityResponseDTO,
        assignment: HomeDTO.Assignment?,
        recruitment: HomeDTO.CurrentRecruitment?,
        application: HomeDTO.Application?
    ) -> MyPageSummary {
        let hasApplied = recruitment?.alreadyApplied == true
        let isApplicationAccepted = hasApplied && application.map { $0.status != .rejected } == true
        return MyPageSummary(
            profile: UserProfile(
                name: user?.name ?? "",
                grade: user?.grade,
                classNumber: user?.classNumber,
                isGuardian: assignment != nil || isApplicationAccepted
            ),
            monthlyApprovedCount: activity.summary.approvedCount,
            monthlyActivityMinutes: activity.monthlyMinutes,
            cleaningAreaName: assignment?.areaName,
            hasApplied: hasApplied
        )
    }
}
