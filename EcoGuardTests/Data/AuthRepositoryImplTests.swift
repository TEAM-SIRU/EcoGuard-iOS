import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct AuthRepositoryImplTests {
    private static let tokens = AuthTokens(accessToken: "access", refreshToken: "refresh")
    private static let logoutPath = "/api/v1/auth/logout"

    private func makeRepository(
        store: InMemoryTokenStore,
        authorizationCode: @escaping () async throws -> String = { "code" },
        handler: @escaping StubURLProtocol.Handler
    ) -> AuthRepositoryImpl {
        let httpClient = HTTPClient(
            baseURL: URL(string: "https://api.example.com")!,
            session: StubURLProtocol.makeSession(handler: handler)
        )
        return AuthRepositoryImpl(
            apiClient: APIClient(httpClient: httpClient, authSession: AuthSession(tokenStore: store, httpClient: httpClient)),
            authorizationCode: authorizationCode
        )
    }

    @Test func logoutSuccessSendsBearerAndClearsTokens() async throws {
        let log = RequestLog()
        let store = InMemoryTokenStore(Self.tokens)
        let repository = makeRepository(store: store) { request in
            log.append(request)
            return (200, Data())
        }

        try await repository.logout()

        let logout = try #require(log.requests(path: Self.logoutPath).first)
        #expect(logout.httpMethod == "POST")
        #expect(logout.value(forHTTPHeaderField: "Authorization") == "Bearer access")
        #expect(store.current == nil)
        #expect(!repository.hasStoredSession())
    }

    @Test(arguments: [500, 0])
    func logoutFailureStillClearsTokens(statusCode: Int) async throws {
        let store = InMemoryTokenStore(Self.tokens)
        let repository = makeRepository(store: store) { _ in
            // 0은 오프라인.
            guard statusCode != 0 else { throw URLError(.notConnectedToInternet) }
            return (statusCode, Data())
        }

        await #expect(throws: (any Error).self) {
            try await repository.logout()
        }
        #expect(store.current == nil)
    }

    @Test func studentLoginStoresTokens() async throws {
        let log = RequestLog()
        let store = InMemoryTokenStore()
        let repository = makeRepository(store: store) { request in
            log.append(request)
            return (200, Self.loginJSON(role: "STUDENT"))
        }

        #expect(try await repository.login() == .student)
        #expect(store.current == AuthTokens(accessToken: "a1", refreshToken: "r1"))
        let body = try JSONDecoder().decode([String: String].self, from: try #require(log.requests.first?.bodyData))
        #expect(body == ["authCode": "code"])
    }

    /// 심사용 코드는 dataGSM 인가를 거치지 않고 그대로 보내며, 성공하면 일반 로그인처럼 토큰을 저장한다.
    @Test func reviewCodeLoginSkipsOAuthAndStoresTokens() async throws {
        let log = RequestLog()
        let store = InMemoryTokenStore()
        let repository = makeRepository(store: store, authorizationCode: { throw AuthError.cancelled }) { request in
            log.append(request)
            return (200, Self.loginJSON(role: "STUDENT"))
        }

        #expect(try await repository.login(authCode: "review-code") == .student)
        #expect(store.current == AuthTokens(accessToken: "a1", refreshToken: "r1"))
        let request = try #require(log.requests.first)
        #expect(request.url?.path == "/api/v1/auth/login")
        let body = try JSONDecoder().decode([String: String].self, from: try #require(request.bodyData))
        #expect(body == ["authCode": "review-code"])
    }

    /// 틀린 심사용 코드는 서버가 401 `OAUTH_FAILED`로 막는다. 토큰을 저장하지 않고 에러를 던진다.
    @Test func wrongReviewCodeThrowsWithoutStoringTokens() async throws {
        let store = InMemoryTokenStore()
        let repository = makeRepository(store: store) { _ in
            (401, Data(#"{"code":"OAUTH_FAILED","message":"failed"}"#.utf8))
        }

        await #expect(throws: (any Error).self) {
            try await repository.login(authCode: "wrong-code")
        }
        #expect(store.current == nil)
    }

    /// 이전 세션 토큰이 남아 있어도 교사로 로그인하면 지운다.
    @Test func teacherLoginDoesNotStoreTokens() async throws {
        let store = InMemoryTokenStore(Self.tokens)
        let repository = makeRepository(store: store) { _ in (200, Self.loginJSON(role: "TEACHER")) }

        #expect(try await repository.login() == .teacher)
        #expect(store.current == nil)
    }

    /// 앱 시작 훅: 저장된 토큰이 있으면 로그인 유지, 없으면 로그인 화면. 서버 주소가 없으면(Mock) 기존대로 로그인 화면.
    @Test func initialLoginStateFollowsStoredSession() throws {
        let defaults = try Self.makeDefaults()
        defaults.set(true, forKey: "auth.hasLaunchedBefore")
        func container(apiBaseURL: URL?, store: InMemoryTokenStore) -> DIContainer {
            DIContainer(
                authRepository: DIContainer.makeAuthRepository(apiBaseURL: apiBaseURL, tokenStore: store, defaults: defaults),
                homeRepository: MockHomeRepository(delay: .zero),
                recruitmentRepository: MockRecruitmentRepository(delay: .zero),
                webAdminURL: nil
            )
        }
        let baseURL = URL(string: "https://api.example.com")

        #expect(container(apiBaseURL: baseURL, store: InMemoryTokenStore(Self.tokens)).makeLoginViewModel().state == .loggedIn)
        #expect(container(apiBaseURL: baseURL, store: InMemoryTokenStore()).makeLoginViewModel().state == .idle)
        #expect(container(apiBaseURL: nil, store: InMemoryTokenStore(Self.tokens)).makeLoginViewModel().state == .idle)
    }

    /// 재설치 후 첫 실행: 키체인에 남은 이전 설치의 토큰을 지운다. 두 번째 실행부터는 유지한다.
    @Test func firstLaunchClearsLeftoverTokens() throws {
        let defaults = try Self.makeDefaults()
        let baseURL = URL(string: "https://api.example.com")
        let leftover = InMemoryTokenStore(Self.tokens)

        let first = DIContainer.makeAuthRepository(apiBaseURL: baseURL, tokenStore: leftover, defaults: defaults)

        #expect(leftover.current == nil)
        #expect(!first.hasStoredSession())

        let stored = InMemoryTokenStore(Self.tokens)
        let second = DIContainer.makeAuthRepository(apiBaseURL: baseURL, tokenStore: stored, defaults: defaults)

        #expect(stored.current == Self.tokens)
        #expect(second.hasStoredSession())
    }

    private static func makeDefaults() throws -> UserDefaults {
        let suiteName = "AuthRepositoryImplTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    nonisolated private static func loginJSON(role: String) -> Data {
        Data(#"{"accessToken":"a1","refreshToken":"r1","user":{"userId":1,"name":"김학생","role":"\#(role)"}}"#.utf8)
    }
}

struct KeychainTokenStoreTests {
    @Test func savesReplacesAndClears() throws {
        let store = KeychainTokenStore(service: "EcoGuardTests.\(UUID().uuidString)")
        defer { store.clear() }
        let first = AuthTokens(accessToken: "a1", refreshToken: "r1")
        let second = AuthTokens(accessToken: "a2", refreshToken: "r2")

        #expect(store.load() == nil)
        try store.save(first)
        #expect(store.load() == first)
        try store.save(second)
        #expect(store.load() == second)
        store.clear()
        #expect(store.load() == nil)
    }
}
