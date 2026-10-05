import Foundation

/// dataGSM OAuth 설정. 인가 코드는 앱이 받고, 토큰 교환은 서버가 `redirectURI`와 함께 한다.
/// 서버가 `code_verifier`를 보내지 않으므로 PKCE(`code_challenge`)는 붙이지 않는다. 붙이면 서버의 토큰 교환이 실패한다.
struct GsmOAuthConfiguration: Equatable {
    /// `GET /v1/oauth/authorize` 주소.
    let authorizeURL: URL
    let clientID: String
    /// dataGSM 클라이언트와 서버(`GSM_OAUTH_REDIRECT_URI`)에 등록한 값과 글자까지 같아야 한다.
    let redirectURI: URL
    let callback: WebAuthenticationCallback

    /// `redirectURI`의 스킴이 https면 https 콜백, 그 밖이면 커스텀 스킴 콜백으로 받는다.
    init?(authorizeURL: URL, clientID: String, redirectURI: URL) {
        guard let scheme = redirectURI.scheme?.lowercased(), let host = redirectURI.host(), !host.isEmpty else { return nil }
        switch scheme {
        case "https":
            callback = .https(host: host, path: redirectURI.path())
        case "http":
            return nil
        default:
            callback = .customScheme(scheme)
        }
        self.authorizeURL = authorizeURL
        self.clientID = clientID
        self.redirectURI = redirectURI
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

    /// 콜백 주소에서 인가 코드를 꺼낸다. `error`가 있거나 `state`가 다르거나 `code`가 없으면 실패다.
    static func authorizationCode(from callbackURL: URL, expectedState: String) throws -> String {
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
}

enum GsmOAuthError: Error, Equatable {
    /// 콜백의 `error` 파라미터 값. dataGSM은 현재 오류를 콜백으로 보내지 않지만 OAuth 표준 응답에 대비한다.
    case authorizationFailed(String)
    /// 요청 때 만든 `state`와 콜백의 `state`가 다르다(CSRF).
    case stateMismatch
    case missingCode
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
        return try GsmOAuthConfiguration.authorizationCode(from: callbackURL, expectedState: state)
    }
}
