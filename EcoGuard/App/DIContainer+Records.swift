import Foundation

extension DIContainer {
    /// 활동 기록을 볼 수 있는 가장 이른 달. 서비스 시작 시점이 정해지기 전까지 2026학년도 1학기 시작(3월)으로 둔다.
    // TODO: 서버 연동 시 서버 값으로 바꾼다.
    static let activityRecordsEarliestMonth = YearMonth(year: 2026, month: 3)

    /// 활동 기록 화면. `repository`를 주지 않으면 서버 주소가 있을 때 실제 저장소, 없으면 Mock.
    func makeActivityRecordsViewModel(
        repository: ActivityRepository? = nil,
        now: @escaping () -> Date = Date.init
    ) -> ActivityRecordsViewModel {
        let repository: ActivityRepository = repository ?? apiClient.map { ActivityRepositoryImpl(apiClient: $0) } ?? MockActivityRepository()
        return ActivityRecordsViewModel(
            fetchActivityMonthUseCase: FetchActivityMonthUseCase(activityRepository: repository),
            earliestMonth: Self.activityRecordsEarliestMonth,
            now: now
        )
    }
}
