protocol AuthRepository {
    /// dataGSM OAuth 로그인 후 계정 역할을 돌려준다.
    func login() async throws -> UserRole
    func logout() async
}
