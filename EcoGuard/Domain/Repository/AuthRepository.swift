protocol AuthRepository {
    /// dataGSM OAuth 로그인 후 계정 역할을 돌려준다. 학생이면 받은 토큰을 저장한다.
    func login() async throws -> UserRole
    /// dataGSM을 거치지 않고 받은 코드(심사용 데모 코드)를 그대로 로그인 요청에 보낸다. 이후 처리는 `login()`과 같다.
    func login(authCode: String) async throws -> UserRole
    /// 서버 세션을 끊고 저장한 토큰을 지운다. 서버 요청이 실패해도 기기의 토큰은 지운 뒤 에러를 던진다.
    func logout() async throws
    /// 저장된 토큰이 있으면 true. 앱 시작 시 로그인 화면을 건너뛸지 정한다.
    func hasStoredSession() -> Bool
    /// 토큰 재발급이 실패해 세션이 끝날 때마다 값을 낸다. 받으면 로그인 화면으로 돌린다.
    func sessionExpirations() -> AsyncStream<Void>
}
