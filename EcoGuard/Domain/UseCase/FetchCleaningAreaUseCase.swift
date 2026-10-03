struct FetchCleaningAreaUseCase {
    private let cleaningAreaRepository: CleaningAreaRepository

    init(cleaningAreaRepository: CleaningAreaRepository) {
        self.cleaningAreaRepository = cleaningAreaRepository
    }

    func execute() async throws -> CleaningAreaSummary {
        try await cleaningAreaRepository.fetchCleaningArea()
    }
}
