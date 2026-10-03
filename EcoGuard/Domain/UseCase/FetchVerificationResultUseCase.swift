struct FetchVerificationResultUseCase {
    private let verificationResultRepository: VerificationResultRepository

    init(verificationResultRepository: VerificationResultRepository) {
        self.verificationResultRepository = verificationResultRepository
    }

    func execute(id: String) async throws -> VerificationResult {
        try await verificationResultRepository.fetchResult(id: id)
    }
}
