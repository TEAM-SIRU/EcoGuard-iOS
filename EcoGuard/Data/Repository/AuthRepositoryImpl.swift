import Foundation

/// 서버 인증. 토큰은 `AuthSession`(키체인)에 둔다.
final class AuthRepositoryImpl: AuthRepository {
    /// 다른 실제 저장소도 같은 `AuthSession`을 쓰도록 `DIContainer`가 꺼내 쓴다.
    let apiClient: APIClient
    private let authSession: AuthSession
    private let authorizationCode: () async throws -> String

    /// `authorizationCode`는 dataGSM OAuth로 받은 인가 코드를 돌려준다.
    init(apiClient: APIClient, authorizationCode: @escaping () async throws -> String) {
        self.apiClient = apiClient
        self.authSession = apiClient.authSession
        self.authorizationCode = authorizationCode
    }

    func login() async throws -> UserRole {
        try await login(authCode: authorizationCode())
    }

    func login(authCode: String) async throws -> UserRole {
        let response: LoginResponseDTO = try await apiClient.send(.login(authCode: authCode))
        guard let role = response.userRole else { throw APIError.decoding }
        // 교사는 앱을 쓰지 않으므로 토큰을 저장하지 않고, 남아 있던 토큰도 지운다(CONVENTION 금지 사항).
        switch role {
        case .student:
            await authSession.save(response.tokens)
            await authSession.saveUser(response.sessionUser)
        case .teacher:
            await authSession.clear()
        }
        return role
    }

    func logout() async throws {
        // 저장한 토큰이 없으면(교사 안내 화면) 서버에 보낼 것이 없다.
        guard authSession.hasStoredSession() else {
            await authSession.clear()
            return
        }
        do {
            try await apiClient.send(.logout)
        } catch {
            await authSession.clear()
            throw error
        }
        await authSession.clear()
    }

    func hasStoredSession() -> Bool {
        authSession.hasStoredSession()
    }

    func sessionExpirations() -> AsyncStream<Void> {
        authSession.expirations.stream()
    }
}
