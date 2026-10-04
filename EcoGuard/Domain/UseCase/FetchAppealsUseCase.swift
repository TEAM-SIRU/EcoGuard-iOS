struct FetchAppealsUseCase {
    private let appealRepository: AppealRepository

    init(appealRepository: AppealRepository) {
        self.appealRepository = appealRepository
    }

    func execute() async throws -> [Appeal] {
        try await appealRepository.fetchAppeals()
    }
}
