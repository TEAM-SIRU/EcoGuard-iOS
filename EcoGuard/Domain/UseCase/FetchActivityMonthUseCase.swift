struct FetchActivityMonthUseCase {
    private let activityRepository: ActivityRepository

    init(activityRepository: ActivityRepository) {
        self.activityRepository = activityRepository
    }

    func execute(_ month: YearMonth) async throws -> ActivityMonth {
        try await activityRepository.fetchMonth(year: month.year, month: month.month)
    }
}
