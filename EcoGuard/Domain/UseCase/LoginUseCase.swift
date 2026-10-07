struct LoginUseCase {
    private let authRepository: AuthRepository

    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
    }

    func execute() async throws -> UserRole {
        try await authRepository.login()
    }

    /// 심사용 데모 코드로 로그인한다.
    func execute(authCode: String) async throws -> UserRole {
        try await authRepository.login(authCode: authCode)
    }
}
