struct ApplyRecruitmentUseCase {
    private let recruitmentRepository: RecruitmentRepository

    init(recruitmentRepository: RecruitmentRepository) {
        self.recruitmentRepository = recruitmentRepository
    }

    /// 앞뒤 공백을 뺀 신청 동기로 신청한다. 입력 규칙은 화면에서 먼저 막고, 여기서 한 번 더 확인한다.
    func execute(motivation: String) async throws -> RecruitmentApplication {
        guard ApplicationMotivation.validate(motivation) == .valid else {
            throw InvalidMotivationError()
        }
        return try await recruitmentRepository.apply(motivation: ApplicationMotivation.trimmed(motivation))
    }

    struct InvalidMotivationError: Error {}
}
