import Foundation
import Testing
@testable import EcoGuard

/// 내 정보(`GET /users/me`)와 회원 탈퇴(`DELETE /users/me`). 받은 사용자는 토큰과 같이 로그아웃·세션 만료·탈퇴 때 지운다.
@MainActor
struct CurrentUserRepositoryTests {
    private static let loginPath = "/api/v1/auth/login"
    private static let refreshPath = "/api/v1/auth/refresh"
    private static let mePath = "/api/v1/users/me"

    private static let profileJSON = #"{"userId":7,"name":"김학생","role":"STUDENT","studentNumber":"2310","grade":2,"classNo":3}"#
    private static let profile = CurrentUser(id: "7", name: "김학생", studentNumber: "2310", grade: 2, classNumber: 3)

    private struct Fixture {
        let auth: AuthRepositoryImpl
        let currentUser: CurrentUserRepositoryImpl
        let userStore: InMemorySessionUserStore
        let authSession: AuthSession
        let log: RequestLog
    }

    /// `responses`: "메서드 경로" → (상태 코드, JSON). 로그인·리프레시는 고정 응답이고 등록하지 않은 요청은 바디 없는 200이다.
    private func makeFixture(
        role: String = "STUDENT",
        tokens: AuthTokens? = nil,
        user: SessionUser? = nil,
        responses: [String: (Int, String)] = [:]
    ) -> Fixture {
        let log = RequestLog()
        let session = StubURLProtocol.makeSession { request in
            log.append(request)
            switch request.url?.path() {
            case Self.loginPath:
                return (200, Data(#"{"accessToken":"a1","refreshToken":"r1","user":{"userId":7,"name":"김학생","role":"\#(role)"}}"#.utf8))
            case Self.refreshPath:
                return (401, Data())
            default:
                let key = "\(request.httpMethod ?? "") \(request.url?.path() ?? "")"
                guard let (statusCode, body) = responses[key] else { return (200, Data()) }
                return (statusCode, Data(body.utf8))
            }
        }
        let httpClient = HTTPClient(baseURL: PathStub.baseURL, session: session)
        let userStore = InMemorySessionUserStore(user)
        let authSession = AuthSession(tokenStore: InMemoryTokenStore(tokens), httpClient: httpClient, userStore: userStore)
        let apiClient = APIClient(httpClient: httpClient, authSession: authSession)
        return Fixture(
            auth: AuthRepositoryImpl(apiClient: apiClient, authorizationCode: { "code" }),
            currentUser: CurrentUserRepositoryImpl(apiClient: apiClient),
            userStore: userStore,
            authSession: authSession,
            log: log
        )
    }

    @Test func fetchMapsProfileAndCachesIt() async throws {
        let fixture = makeFixture(tokens: PathStub.tokens, responses: ["GET \(Self.mePath)": (200, Self.profileJSON)])

        let user = try await FetchCurrentUserUseCase(currentUserRepository: fixture.currentUser).execute()

        #expect(user == Self.profile)
        let request = try #require(fixture.log.requests(path: Self.mePath).first)
        #expect(request.httpMethod == "GET")
        #expect(request.bearerToken == PathStub.tokens.accessToken)
        #expect(fixture.userStore.load() == SessionUser(userId: 7, name: "김학생", studentNumber: "2310", grade: 2, classNo: 3))
    }

    /// 학번·학년·반은 학생 계정에만 있다(dataGSM에 없으면 null).
    @Test func missingStudentFieldsAreNil() async throws {
        let fixture = makeFixture(
            tokens: PathStub.tokens,
            responses: ["GET \(Self.mePath)": (200, #"{"userId":7,"name":"김학생","role":"STUDENT","studentNumber":null,"grade":null,"classNo":null}"#)]
        )

        let user = try await fixture.currentUser.fetchCurrentUser()

        #expect(user == CurrentUser(id: "7", name: "김학생", studentNumber: nil, grade: nil, classNumber: nil))
    }

    /// 내 정보를 받지 못하면 로그인 때 저장한 값(이름만)으로 보여 준다.
    @Test(arguments: [500, 404])
    func failureFallsBackToCachedUser(statusCode: Int) async throws {
        let fixture = makeFixture(
            tokens: PathStub.tokens,
            user: SessionUser(userId: 7, name: "김학생"),
            responses: ["GET \(Self.mePath)": (statusCode, PathStub.error("USER_NOT_FOUND"))]
        )

        let user = try await fixture.currentUser.fetchCurrentUser()

        #expect(user == CurrentUser(id: "7", name: "김학생", studentNumber: nil, grade: nil, classNumber: nil))
    }

    @Test func failureWithoutCacheThrows() async {
        let fixture = makeFixture(tokens: PathStub.tokens, responses: ["GET \(Self.mePath)": (500, "")])

        await #expect(throws: APIError.server(statusCode: 500, code: nil)) {
            try await fixture.currentUser.fetchCurrentUser()
        }
    }

    /// 세션이 만료되면 저장한 값도 지워지므로 대신 보여 주지 않는다.
    @Test func sessionExpiryDuringFetchThrows() async {
        let fixture = makeFixture(
            tokens: PathStub.tokens,
            user: SessionUser(userId: 7, name: "김학생"),
            responses: ["GET \(Self.mePath)": (401, "")]
        )

        await #expect(throws: APIError.sessionExpired) {
            try await fixture.currentUser.fetchCurrentUser()
        }
        #expect(fixture.userStore.load() == nil)
    }

    /// 요청하는 사이 다시 로그인했거나 로그아웃했으면 그 전에 보낸 요청의 응답을 저장하지 않는다.
    @Test func updateFromPreviousSessionIsIgnored() async throws {
        let fixture = makeFixture(tokens: PathStub.tokens)
        let generation = await fixture.authSession.sessionGeneration()

        await fixture.authSession.save(AuthTokens(accessToken: "a2", refreshToken: "r2"))
        await fixture.authSession.updateUser(SessionUser(userId: 1, name: "이전 학생"), startedIn: generation)
        #expect(fixture.userStore.load() == nil)

        await fixture.authSession.clear()
        await fixture.authSession.updateUser(SessionUser(userId: 1, name: "이전 학생"), startedIn: await fixture.authSession.sessionGeneration())
        #expect(fixture.userStore.load() == nil)
    }

    @Test func studentLoginStoresUserAndLogoutClearsIt() async throws {
        let fixture = makeFixture()

        _ = try await fixture.auth.login()
        #expect(fixture.userStore.load() == SessionUser(userId: 7, name: "김학생"))

        try await fixture.auth.logout()
        #expect(fixture.userStore.load() == nil)
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

        #expect(fixture.userStore.load() == nil)
    }

    @Test func withdrawSendsDeleteAndClearsSession() async throws {
        let fixture = makeFixture(tokens: PathStub.tokens, user: SessionUser(userId: 7, name: "김학생"))

        try await WithdrawUseCase(currentUserRepository: fixture.currentUser).execute()

        let request = try #require(fixture.log.requests(path: Self.mePath).first)
        #expect(request.httpMethod == "DELETE")
        #expect(request.bearerToken == PathStub.tokens.accessToken)
        #expect(!fixture.auth.hasStoredSession())
        #expect(fixture.userStore.load() == nil)
    }

    /// 탈퇴가 실패하면(교사 계정 403 포함) 계정이 남아 있으므로 로그인을 유지한다.
    @Test(arguments: [(500, nil), (403, "FORBIDDEN")] as [(Int, String?)])
    func failedWithdrawKeepsSession(statusCode: Int, code: String?) async throws {
        let fixture = makeFixture(
            tokens: PathStub.tokens,
            user: SessionUser(userId: 7, name: "김학생"),
            responses: ["DELETE \(Self.mePath)": (statusCode, code.map { PathStub.error($0) } ?? "")]
        )

        await #expect(throws: APIError.server(statusCode: statusCode, code: code)) {
            try await fixture.currentUser.withdraw()
        }

        #expect(fixture.auth.hasStoredSession())
        #expect(fixture.userStore.load() == SessionUser(userId: 7, name: "김학생"))
    }

    @Test func userDefaultsStoreRoundTrips() throws {
        let suiteName = "CurrentUserRepositoryTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsSessionUserStore(defaults: defaults)
        let user = SessionUser(userId: 7, name: "김학생", studentNumber: "2310", grade: 2, classNo: 3)

        #expect(store.load() == nil)
        store.save(user)
        #expect(UserDefaultsSessionUserStore(defaults: defaults).load() == user)
        defaults.set(["7"], forKey: HomeRepositoryImpl.dismissedNoticeIDsKey)
        store.clear()
        #expect(store.load() == nil)
        // 닫은 공지도 다음 사용자에게 남지 않는다.
        #expect(defaults.stringArray(forKey: HomeRepositoryImpl.dismissedNoticeIDsKey) == nil)
    }

    /// 이전 버전이 저장한 값(이름만)도 읽힌다. 업데이트 뒤 다시 로그인하지 않아도 된다.
    @Test func storedUserFromPreviousVersionDecodes() throws {
        let suiteName = "CurrentUserRepositoryTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data(#"{"userId":7,"name":"김학생"}"#.utf8), forKey: "auth.sessionUser")

        #expect(UserDefaultsSessionUserStore(defaults: defaults).load() == SessionUser(userId: 7, name: "김학생"))
    }
}
