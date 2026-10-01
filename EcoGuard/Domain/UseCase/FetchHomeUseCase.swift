struct FetchHomeUseCase {
    private let homeRepository: HomeRepository

    init(homeRepository: HomeRepository) {
        self.homeRepository = homeRepository
    }

    func execute() async throws -> HomeSummary {
        try await homeRepository.fetchHome()
    }
}
