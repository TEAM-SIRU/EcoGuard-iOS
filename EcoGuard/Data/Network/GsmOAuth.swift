import Foundation

/// dataGSM OAuth 설정. 인가 코드는 앱이 받고, 토큰 교환은 서버가 `redirectURI`와 함께 한다.
/// 서버가 `code_verifier`를 보내지 않으므로 PKCE(`code_challenge`)는 붙이지 않는다. 붙이면 서버의 토큰 교환이 실패한다.
///
/// 흐름: dataGSM 인가 → `redirectURI`(서버 `/api/v1/auth/callback`) → 서버가 `callbackURL`(`ecoguard://auth/callback?code&state`)로 302
/// → 앱이 받아 state를 확인하고 `POST /api/v1/auth/login`.
struct GsmOAuthConfiguration: Equatable {
    /// `GET /v1/oauth/authorize` 주소.
    let authorizeURL: URL
    let clientID: String
    /// dataGSM에 보내는 `redirect_uri`. dataGSM 클라이언트와 서버(`GSM_OAUTH_REDIRECT_URI`)에 등록한 값과 글자까지 같아야 한다.
    let redirectURI: URL
    /// 서버가 인가 코드를 붙여 돌려보내는 앱 주소. 스킴·호스트·경로가 모두 같은 콜백만 받는다.
    let callbackURL: URL
    let callback: WebAuthenticationCallback

    /// `callbackURL`의 스킴이 https면 https 콜백, 그 밖이면 커스텀 스킴 콜백으로 받는다.
    /// 커스텀 스킴은 `ASWebAuthenticationSession`에 스킴을 넘기면 받으므로 Info.plist `CFBundleURLTypes` 등록이 필요 없다.
    /// https 콜백은 Associated Domains(`webcredentials:`) 엔타이틀먼트와 서버의 apple-app-site-association이 있어야 한다.
    /// 둘 중 하나라도 없으면 인가 후 콜백이 앱으로 오지 않는다(아직 미설정).
    init?(authorizeURL: URL, clientID: String, redirectURI: URL, callbackURL: URL) {
        guard Self.hasHost(redirectURI), redirectURI.scheme?.lowercased() != "http",
              Self.hasHost(callbackURL), let scheme = callbackURL.scheme?.lowercased(), let host = callbackURL.host()
        else { return nil }
        switch scheme {
        case "https":
            callback = .https(host: host, path: WebAuthenticationCallback.normalizedPath(callbackURL.path()))
        case "http":
            return nil
        default:
            callback = .customScheme(scheme)
        }
        self.authorizeURL = authorizeURL
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.callbackURL = callbackURL
    }

    private static func hasHost(_ url: URL) -> Bool {
        url.scheme != nil && !(url.host() ?? "").isEmpty
    }

    /// dataGSM은 콜백 주소에 `state`를 인코딩 없이 붙이므로 URL에 안전한 값(UUID)만 넘긴다.
    func authorizationURL(state: String) -> URL {
        guard var components = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false) else { return authorizeURL }
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "state", value: state)
        ]
        return components.url ?? authorizeURL
    }

    /// 콜백 주소에서 인가 코드를 꺼낸다. 주소가 `callbackURL`과 다르거나 `error`가 있거나 `state`가 다르거나 `code`가 없으면 실패다.
    func authorizationCode(from callbackURL: URL, expectedState: String) throws -> String {
        guard matchesCallback(callbackURL) else { throw GsmOAuthError.unexpectedCallback }
        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }
        if let error = value("error") {
            throw GsmOAuthError.authorizationFailed(error)
        }
        guard value("state") == expectedState else { throw GsmOAuthError.stateMismatch }
        guard let code = value("code"), !code.isEmpty else { throw GsmOAuthError.missingCode }
        return code
    }

    /// 커스텀 스킴 콜백은 시스템이 스킴만 맞춰 돌려주므로 호스트·경로는 여기서 확인한다. 스킴·호스트는 대소문자를 가리지 않는다.
    private func matchesCallback(_ url: URL) -> Bool {
        url.scheme?.lowercased() == callbackURL.scheme?.lowercased()
            && url.host()?.lowercased() == callbackURL.host()?.lowercased()
            && WebAuthenticationCallback.normalizedPath(url.path()) == WebAuthenticationCallback.normalizedPath(callbackURL.path())
    }
}

enum GsmOAuthError: Error, Equatable {
    /// 콜백의 `error` 파라미터 값. dataGSM은 현재 오류를 콜백으로 보내지 않지만 OAuth 표준 응답에 대비한다.
    case authorizationFailed(String)
    /// 요청 때 만든 `state`와 콜백의 `state`가 다르다(CSRF).
    case stateMismatch
    case missingCode
    /// 콜백 주소의 호스트·경로가 설정한 `callbackURL`과 다르다.
    case unexpectedCallback
}

/// dataGSM 인가 화면을 띄워 인가 코드를 받는다. 사용자가 창을 닫으면 `AuthError.cancelled`를 던진다.
final class GsmOAuthAuthorizer {
    private let configuration: GsmOAuthConfiguration
    private let session: WebAuthenticationSession
    private let makeState: () -> String

    init(
        configuration: GsmOAuthConfiguration,
        session: WebAuthenticationSession,
        makeState: @escaping () -> String = { UUID().uuidString }
    ) {
        self.configuration = configuration
        self.session = session
        self.makeState = makeState
    }

    func authorizationCode() async throws -> String {
        let state = makeState()
        let callbackURL = try await session.authenticate(
            url: configuration.authorizationURL(state: state),
            callback: configuration.callback
        )
        return try configuration.authorizationCode(from: callbackURL, expectedState: state)
    }
}
