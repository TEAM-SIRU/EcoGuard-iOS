/// 로그인 응답에서 저장한 사용자 요약. 토큰과 같이 `AuthSession`이 지운다.
final class CurrentUserRepositoryImpl: CurrentUserRepository {
    private let authSession: AuthSession

    init(authSession: AuthSession) {
        self.authSession = authSession
    }

    func currentUser() -> CurrentUser? {
        authSession.currentUser().map { CurrentUser(id: String($0.userId), name: $0.name) }
    }
}
