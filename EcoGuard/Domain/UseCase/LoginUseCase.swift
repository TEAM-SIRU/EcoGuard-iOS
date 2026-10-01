struct LoginUseCase {
    private let authRepository: AuthRepository

    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
    }

    func execute() async throws -> UserRole {
        try await authRepository.login()
    }
}
