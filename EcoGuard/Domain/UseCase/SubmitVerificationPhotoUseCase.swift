struct SubmitVerificationPhotoUseCase {
    private let verificationRepository: VerificationRepository

    init(verificationRepository: VerificationRepository) {
        self.verificationRepository = verificationRepository
    }

    func execute(_ photo: VerificationPhoto) async throws -> VerificationSubmission {
        try await verificationRepository.submit(photo)
    }
}
