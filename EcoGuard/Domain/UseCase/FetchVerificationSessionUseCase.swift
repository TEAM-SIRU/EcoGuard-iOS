struct FetchVerificationSessionUseCase {
    private let verificationRepository: VerificationRepository

    init(verificationRepository: VerificationRepository) {
        self.verificationRepository = verificationRepository
    }

    func execute() async throws -> VerificationSession {
        try await verificationRepository.fetchSession()
    }
}
