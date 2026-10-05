import AuthenticationServices
import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct GsmOAuthTests {
    private static let state = "3F2504E0-4F89-11D3-9A0C-0305E82C3301"

    private static func makeConfiguration(redirectURI: String = "ecoguard://oauth/callback") -> GsmOAuthConfiguration? {
        GsmOAuthConfiguration(
            authorizeURL: URL(string: "https://oauth.authorization.datagsm.kr/v1/oauth/authorize")!,
            clientID: "client-1",
            redirectURI: URL(string: redirectURI)!
        )
    }

    /// 인가 화면을 띄우는 대신 요청 주소를 기록하고, 그 주소를 받아 콜백 주소(또는 에러)를 만든다.
    private final class FakeWebAuthenticationSession: WebAuthenticationSession {
        private(set) var requests: [(url: URL, callback: WebAuthenticationCallback)] = []
        private let respond: (URL) throws -> URL

        init(respond: @escaping (URL) throws -> URL) {
            self.respond = respond
        }

        func authenticate(url: URL, callback: WebAuthenticationCallback) async throws -> URL {
            requests.append((url, callback))
            return try respond(url)
        }
    }

    private static func query(_ url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    // MARK: - 인가 주소

    /// 서버가 `code_verifier`를 보내지 않으므로 PKCE 파라미터는 붙이지 않는다.
    @Test func authorizationURLHasDataGsmParameters() throws {
        let configuration = try #require(Self.makeConfiguration())
        let url = configuration.authorizationURL(state: Self.state)

        #expect(url.host() == "oauth.authorization.datagsm.kr")
        #expect(url.path() == "/v1/oauth/authorize")
        #expect(Self.query(url) == [
            "client_id": "client-1",
            "redirect_uri": "ecoguard://oauth/callback",
            "response_type": "code",
            "state": Self.state
        ])
    }

    @Test func callbackFollowsRedirectScheme() throws {
        #expect(try #require(Self.makeConfiguration()).callback == .customScheme("ecoguard"))
        #expect(
            try #require(Self.makeConfiguration(redirectURI: "https://eco.example.com/oauth/callback")).callback
                == .https(host: "eco.example.com", path: "/oauth/callback")
        )
        #expect(Self.makeConfiguration(redirectURI: "http://eco.example.com/oauth/callback") == nil)
        #expect(Self.makeConfiguration(redirectURI: "ecoguard:callback") == nil)
    }

    // MARK: - 콜백 파싱

    @Test func callbackWithMatchingStateReturnsCode() throws {
        let url = URL(string: "ecoguard://oauth/callback?code=abc123&state=\(Self.state)")!
        #expect(try GsmOAuthConfiguration.authorizationCode(from: url, expectedState: Self.state) == "abc123")
    }

    @Test(arguments: [
        "ecoguard://oauth/callback?code=abc123&state=other",
        "ecoguard://oauth/callback?code=abc123"
    ])
    func stateMismatchThrows(callback: String) {
        #expect(throws: GsmOAuthError.stateMismatch) {
            try GsmOAuthConfiguration.authorizationCode(from: URL(string: callback)!, expectedState: Self.state)
        }
    }

    @Test(arguments: ["ecoguard://oauth/callback?state=", "ecoguard://oauth/callback?code=&state="])
    func missingCodeThrows(prefix: String) {
        let url = URL(string: prefix + Self.state)!
        #expect(throws: GsmOAuthError.missingCode) {
            try GsmOAuthConfiguration.authorizationCode(from: url, expectedState: Self.state)
        }
    }

    /// `error`가 오면 state·code보다 먼저 실패로 본다.
    @Test func errorParameterThrows() {
        let url = URL(string: "ecoguard://oauth/callback?error=access_denied&state=\(Self.state)")!
        #expect(throws: GsmOAuthError.authorizationFailed("access_denied")) {
            try GsmOAuthConfiguration.authorizationCode(from: url, expectedState: Self.state)
        }
    }

    // MARK: - 인가 흐름

    @Test func authorizerSendsStateAndReturnsCode() async throws {
        let session = FakeWebAuthenticationSession { url in
            let state = try #require(Self.query(url)["state"])
            return URL(string: "ecoguard://oauth/callback?code=abc123&state=\(state)")!
        }
        let authorizer = GsmOAuthAuthorizer(
            configuration: try #require(Self.makeConfiguration()),
            session: session,
            makeState: { Self.state }
        )

        #expect(try await authorizer.authorizationCode() == "abc123")
        #expect(session.requests.count == 1)
        #expect(session.requests.first?.callback == .customScheme("ecoguard"))
    }

    /// 매번 새 state를 만들어, 이전 요청의 콜백을 그대로 돌려받으면 거절한다.
    @Test func authorizerRejectsReplayedState() async throws {
        let session = FakeWebAuthenticationSession { _ in
            URL(string: "ecoguard://oauth/callback?code=abc123&state=\(Self.state)")!
        }
        let authorizer = GsmOAuthAuthorizer(configuration: try #require(Self.makeConfiguration()), session: session)

        await #expect(throws: GsmOAuthError.stateMismatch) {
            try await authorizer.authorizationCode()
        }
    }

    @Test func authorizerPassesCancellationThrough() async throws {
        let session = FakeWebAuthenticationSession { _ in throw AuthError.cancelled }
        let authorizer = GsmOAuthAuthorizer(configuration: try #require(Self.makeConfiguration()), session: session)

        await #expect(throws: AuthError.cancelled) {
            try await authorizer.authorizationCode()
        }
    }

    /// 사용자가 창을 닫은 것만 취소로 바꾸고, 다른 웹 인증 에러는 실패로 둔다.
    @Test func systemSessionMapsOnlyCanceledLoginToCancelled() {
        let cancelled = SystemWebAuthenticationSession.mapError(ASWebAuthenticationSessionError(.canceledLogin))
        #expect(cancelled as? AuthError == .cancelled)

        let other = SystemWebAuthenticationSession.mapError(ASWebAuthenticationSessionError(.presentationContextInvalid))
        #expect(other as? AuthError == nil)
        #expect((other as? ASWebAuthenticationSessionError)?.code == .presentationContextInvalid)
    }

    /// 사용자가 인가 창을 닫으면 로그인 화면은 실패 안내 없이 처음 상태로 돌아간다.
    @Test func cancelledAuthorizationLeavesLoginIdle() async throws {
        let session = FakeWebAuthenticationSession { _ in throw AuthError.cancelled }
        let authorizer = GsmOAuthAuthorizer(configuration: try #require(Self.makeConfiguration()), session: session)
        let httpClient = HTTPClient(
            baseURL: URL(string: "https://api.example.com")!,
            session: StubURLProtocol.makeSession { _ in (500, Data()) }
        )
        let repository = AuthRepositoryImpl(
            apiClient: APIClient(
                httpClient: httpClient,
                authSession: AuthSession(tokenStore: InMemoryTokenStore(), httpClient: httpClient)
            ),
            authorizationCode: { try await authorizer.authorizationCode() }
        )
        let viewModel = LoginViewModel(
            loginUseCase: LoginUseCase(authRepository: repository),
            logoutUseCase: LogoutUseCase(authRepository: repository)
        )

        await viewModel.login()

        #expect(viewModel.state == .idle)
    }
}
