protocol AuthRepository {
    /// dataGSM OAuth 로그인 후 계정 역할을 돌려준다.
    func login() async throws -> UserRole
    /// 서버 세션을 끊고 저장한 토큰을 지운다. 서버 요청이 실패해도 기기의 토큰은 지운 뒤 에러를 던진다.
    func logout() async throws
}
