import Foundation
import os

/// 빌드 설정에서 Info.plist로 주입한 앱 설정 값.
enum AppConfig {
    /// Info.plist `EcoWebAdminURL` = `https://$(ECO_WEB_ADMIN_HOST)`.
    /// xcconfig는 `//`를 주석으로 읽으므로 빌드 설정에는 스킴 없이 호스트(경로 포함 가능)만 넣는다.
    static let webAdminURLPrefix = "https://"

    private static let logger = Logger(subsystem: "EcoGuard", category: "AppConfig")

    /// 교사용 웹 관리자 주소. 주소가 정해지기 전까지 빈 값이며, 그동안 교사 안내 화면의 복사·공유 버튼은 숨긴다.
    static var webAdminURL: URL? {
        webAdminURL(from: bundledWebAdminURLString)
    }

    static var bundledWebAdminURLString: String? {
        Bundle.main.object(forInfoDictionaryKey: "EcoWebAdminURL") as? String
    }

    /// `https://` 뒤 호스트가 채워져 있으면 true. 비어 있으면 아직 주소가 정해지지 않은 것이다.
    static func isWebAdminHostConfigured(_ rawValue: String?) -> Bool {
        guard var value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        if value.hasPrefix(webAdminURLPrefix) {
            value.removeFirst(webAdminURLPrefix.count)
        }
        return !value.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// 호스트가 비어 있으면 nil. 값이 있는데 올바른 https 주소가 아니면 DEBUG 빌드에서 로그를 남기고 nil.
    static func webAdminURL(from rawValue: String?) -> URL? {
        configuredURL(from: rawValue, key: "EcoWebAdminURL")
    }

    /// Info.plist `EcoAPIBaseURL` = `https://$(ECO_API_HOST)`. 비어 있으면 `DIContainer.live()`는 Mock 저장소를 쓴다.
    static var apiBaseURL: URL? {
        apiBaseURL(from: Bundle.main.object(forInfoDictionaryKey: "EcoAPIBaseURL") as? String)
    }

    static func apiBaseURL(from rawValue: String?) -> URL? {
        configuredURL(from: rawValue, key: "EcoAPIBaseURL")
    }

    /// 서버 주소가 있어도 Mock 저장소를 쓸지. DEBUG 빌드에서 환경 변수 `ECO_USE_MOCK=1`이면(스킴 Run › Environment Variables에서 켠다)
    /// Mock을 쓴다. 테스트 호스트로 실행될 때도 실서버·키체인을 건드리지 않게 Mock을 쓴다.
    static var usesMockRepositories: Bool {
        usesMockRepositories(environment: ProcessInfo.processInfo.environment)
    }

    static func usesMockRepositories(environment: [String: String]) -> Bool {
        if environment["XCTestConfigurationFilePath"] != nil { return true }
        #if DEBUG
        return environment["ECO_USE_MOCK"] == "1"
        #else
        return false
        #endif
    }

    /// dataGSM OAuth 설정. Info.plist `EcoOAuthAuthorizeURL` = `https://$(ECO_OAUTH_AUTHORIZE_HOST)`,
    /// `EcoOAuthClientID` = `$(ECO_OAUTH_CLIENT_ID)`, `EcoOAuthRedirectURI` = `$(ECO_OAUTH_REDIRECT_URI)`(dataGSM에 보내는 서버 콜백),
    /// `EcoOAuthCallbackURL` = `$(ECO_OAUTH_CALLBACK_URL)`(서버가 돌려보내는 앱 주소).
    /// 값이 하나라도 비어 있으면 nil이며, 그동안 실제 모드(서버 주소 있음) 로그인은 실패한다.
    static var gsmOAuthConfiguration: GsmOAuthConfiguration? {
        gsmOAuthConfiguration(
            authorizeURL: Bundle.main.object(forInfoDictionaryKey: "EcoOAuthAuthorizeURL") as? String,
            clientID: Bundle.main.object(forInfoDictionaryKey: "EcoOAuthClientID") as? String,
            redirectURI: Bundle.main.object(forInfoDictionaryKey: "EcoOAuthRedirectURI") as? String,
            callbackURL: Bundle.main.object(forInfoDictionaryKey: "EcoOAuthCallbackURL") as? String
        )
    }

    static func gsmOAuthConfiguration(
        authorizeURL: String?,
        clientID: String?,
        redirectURI: String?,
        callbackURL: String?
    ) -> GsmOAuthConfiguration? {
        let clientID = clientID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let redirectURI = redirectURI?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let callbackURL = callbackURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !clientID.isEmpty, !redirectURI.isEmpty, !callbackURL.isEmpty,
              let authorizeURL = configuredURL(from: authorizeURL, key: "EcoOAuthAuthorizeURL")
        else { return nil }
        guard let redirect = URL(string: redirectURI), let callback = URL(string: callbackURL),
              let configuration = GsmOAuthConfiguration(
                  authorizeURL: authorizeURL,
                  clientID: clientID,
                  redirectURI: redirect,
                  callbackURL: callback
              )
        else {
            #if DEBUG
            logger.error("EcoOAuthRedirectURI·EcoOAuthCallbackURL 값이 올바른 주소가 아니다: \(redirectURI, privacy: .public) / \(callbackURL, privacy: .public)")
            #endif
            return nil
        }
        return configuration
    }

    private static func configuredURL(from rawValue: String?, key: String) -> URL? {
        guard isWebAdminHostConfigured(rawValue),
              let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        else { return nil }
        guard let url = validatedURL(trimmed) else {
            #if DEBUG
            logger.error("\(key, privacy: .public) 값이 올바른 https 주소가 아니다: \(trimmed, privacy: .public)")
            #endif
            return nil
        }
        return url
    }

    private static func validatedURL(_ value: String) -> URL? {
        guard value.hasPrefix(webAdminURLPrefix) else { return nil }
        let host = value.dropFirst(webAdminURLPrefix.count)
        // 빌드 설정에 스킴까지 넣어 `https://https://…`가 된 경우.
        guard !host.contains("://"),
              let components = URLComponents(string: value),
              let componentsHost = components.host,
              !componentsHost.isEmpty
        else { return nil }
        return components.url
    }
}
