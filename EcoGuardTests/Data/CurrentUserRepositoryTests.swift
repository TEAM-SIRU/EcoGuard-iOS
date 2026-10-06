import Foundation
import Testing
@testable import EcoGuard

/// 로그인 응답의 사용자 요약을 저장했다가 로그아웃·세션 만료·교사 로그인 때 토큰과 같이 지운다.
@MainActor
struct CurrentUserRepositoryTests {
    private static let loginPath = "/api/v1/auth/login"
    private static let refreshPath = "/api/v1/auth/refresh"

    private struct Fixture {
        let auth: AuthRepositoryImpl
        let currentUser: CurrentUserRepositoryImpl
        let userStore: InMemorySessionUserStore
        let authSession: AuthSession
    }

    private func makeFixture(role: String = "STUDENT", tokens: AuthTokens? = nil, user: SessionUser? = nil) -> Fixture {
        let session = StubURLProtocol.makeSession { request in
            switch request.url?.path() {
            case Self.loginPath:
                return (200, Data(#"{"accessToken":"a1","refreshToken":"r1","user":{"userId":7,"name":"김학생","role":"\#(role)"}}"#.utf8))
            case Self.refreshPath:
                return (401, Data())
            default:
                return (200, Data())
            }
        }
        let httpClient = HTTPClient(baseURL: PathStub.baseURL, session: session)
        let userStore = InMemorySessionUserStore(user)
        let authSession = AuthSession(tokenStore: InMemoryTokenStore(tokens), httpClient: httpClient, userStore: userStore)
        return Fixture(
            auth: AuthRepositoryImpl(apiClient: APIClient(httpClient: httpClient, authSession: authSession), authorizationCode: { "code" }),
            currentUser: CurrentUserRepositoryImpl(authSession: authSession),
            userStore: userStore,
            authSession: authSession
        )
    }

    @Test func studentLoginStoresUserAndLogoutClearsIt() async throws {
        let fixture = makeFixture()

        _ = try await fixture.auth.login()
        #expect(fixture.currentUser.currentUser() == CurrentUser(id: "7", name: "김학생"))
        #expect(FetchCurrentUserUseCase(currentUserRepository: fixture.currentUser).execute()?.name == "김학생")

        try await fixture.auth.logout()
        #expect(fixture.currentUser.currentUser() == nil)
    }

    @Test func teacherLoginClearsPreviousUser() async throws {
        let fixture = makeFixture(role: "TEACHER", user: SessionUser(userId: 1, name: "이전 학생"))

        _ = try await fixture.auth.login()

        #expect(fixture.userStore.load() == nil)
    }

    /// 리프레시 토큰이 무효(401)라 세션이 만료되면 사용자도 지운다.
    @Test func sessionExpiryClearsUser() async throws {
        let fixture = makeFixture(tokens: PathStub.tokens, user: SessionUser(userId: 7, name: "김학생"))

        await #expect(throws: APIError.sessionExpired) {
            try await fixture.authSession.validAccessToken(replacing: PathStub.tokens.accessToken)
        }

        #expect(fixture.currentUser.currentUser() == nil)
    }

    @Test func userDefaultsStoreRoundTrips() throws {
        let suiteName = "CurrentUserRepositoryTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsSessionUserStore(defaults: defaults)

        #expect(store.load() == nil)
        store.save(SessionUser(userId: 7, name: "김학생"))
        #expect(UserDefaultsSessionUserStore(defaults: defaults).load() == SessionUser(userId: 7, name: "김학생"))
        defaults.set(["7"], forKey: HomeRepositoryImpl.dismissedNoticeIDsKey)
        store.clear()
        #expect(store.load() == nil)
        // 닫은 공지도 다음 사용자에게 남지 않는다.
        #expect(defaults.stringArray(forKey: HomeRepositoryImpl.dismissedNoticeIDsKey) == nil)
    }
}
