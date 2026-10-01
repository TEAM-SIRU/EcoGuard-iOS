struct FetchMyApplicationUseCase {
    private let recruitmentRepository: RecruitmentRepository

    init(recruitmentRepository: RecruitmentRepository) {
        self.recruitmentRepository = recruitmentRepository
    }

    func execute() async throws -> RecruitmentApplication? {
        try await recruitmentRepository.fetchMyApplication()
    }
}
