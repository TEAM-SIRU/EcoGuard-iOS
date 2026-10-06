import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct AppConfigTests {
    /// 빌드 설정 `ECO_WEB_ADMIN_HOST`가 비어 있으면 Info.plist 값은 `https://`만 남는다. 버튼을 숨긴다.
    @Test(arguments: [nil, "", "https://", "https://   "] as [String?])
    func emptyHostHidesWebLinkActions(rawValue: String?) {
        #expect(!AppConfig.isWebAdminHostConfigured(rawValue))
        #expect(AppConfig.webAdminURL(from: rawValue) == nil)
    }

    /// 값은 있지만 올바른 https 주소가 아니면 버튼을 숨긴다(DEBUG에서는 로그를 남긴다).
    @Test(arguments: [
        "https://https://example.com",
        "https://exa mple.com",
        "https://:8080",
        "http://example.com",
        "example.com",
        "javascript:alert(1)"
    ])
    func invalidHostHidesWebLinkActions(rawValue: String) {
        #expect(AppConfig.isWebAdminHostConfigured(rawValue))
        #expect(AppConfig.webAdminURL(from: rawValue) == nil)
    }

    /// 예시 주소는 테스트에서만 쓴다(example.com은 문서용 예약 도메인).
    @Test(arguments: ["https://example.com", "https://example.com/admin", "  https://example.com/  "])
    func validHostShowsWebLinkActions(rawValue: String) {
        #expect(AppConfig.webAdminURL(from: rawValue)?.host() == "example.com")
    }

    /// 빌드 설정에 호스트를 넣었다면 번들 값은 올바른 주소여야 한다. 비어 있으면(주소 미정) 건너뛴다.
    @Test(.enabled { await AppConfig.isWebAdminHostConfigured(AppConfig.bundledWebAdminURLString) })
    func bundledValueIsValidWhenConfigured() {
        #expect(AppConfig.webAdminURL != nil)
    }

    // MARK: - dataGSM OAuth

    private static let authorizeURL = "https://oauth.authorization.datagsm.kr/v1/oauth/authorize"

    private static let redirectURI = "https://ecoguard.https.gsmsv.site/api/v1/auth/callback"
    private static let callbackURL = "ecoguard://auth/callback"

    /// 클라이언트 ID·리다이렉트 URI·콜백 주소 빌드 설정 중 하나라도 비었거나 잘못되면 설정이 없는 것으로 본다.
    @Test(arguments: [
        ("", redirectURI, callbackURL),
        ("  ", redirectURI, callbackURL),
        ("client-1", "", callbackURL),
        ("client-1", redirectURI, ""),
        ("client-1", "http://example.com/callback", callbackURL),
        ("client-1", redirectURI, "ecoguard:callback"),
        ("client-1", redirectURI, "http://example.com/callback")
    ])
    func incompleteOAuthSettingsAreIgnored(clientID: String, redirectURI: String, callbackURL: String) {
        #expect(AppConfig.gsmOAuthConfiguration(
            authorizeURL: Self.authorizeURL,
            clientID: clientID,
            redirectURI: redirectURI,
            callbackURL: callbackURL
        ) == nil)
    }

    @Test func emptyAuthorizeHostIsIgnored() {
        #expect(AppConfig.gsmOAuthConfiguration(
            authorizeURL: "https://",
            clientID: "client-1",
            redirectURI: Self.redirectURI,
            callbackURL: Self.callbackURL
        ) == nil)
    }

    /// dataGSM에는 서버 콜백(https)을 보내고, 앱은 서버가 302로 돌려보내는 커스텀 스킴 주소를 받는다.
    @Test func filledOAuthSettingsMakeConfiguration() throws {
        let configuration = try #require(AppConfig.gsmOAuthConfiguration(
            authorizeURL: Self.authorizeURL,
            clientID: " client-1 ",
            redirectURI: " \(Self.redirectURI) ",
            callbackURL: Self.callbackURL
        ))
        #expect(configuration.clientID == "client-1")
        #expect(configuration.redirectURI.absoluteString == Self.redirectURI)
        #expect(configuration.callbackURL.absoluteString == Self.callbackURL)
        #expect(configuration.callback == .customScheme("ecoguard"))
    }

    /// 번들에 넣은 실제 설정값이 올바르게 읽히는지. 서버 주소와 dataGSM·서버에 등록한 redirect_uri가 맞아야 한다.
    @Test func bundledOAuthSettingsMatchServer() throws {
        let configuration = try #require(AppConfig.gsmOAuthConfiguration)
        #expect(configuration.clientID == "ee25e2c7-d27f-4a9d-8378-b135fc679b84")
        #expect(configuration.redirectURI.absoluteString == Self.redirectURI)
        #expect(configuration.callbackURL.absoluteString == Self.callbackURL)
        #expect(AppConfig.apiBaseURL?.absoluteString == "https://ecoguard.https.gsmsv.site")
    }

    // MARK: - Mock 전환

    /// 테스트 호스트로 실행되면 서버 주소가 있어도 Mock을 써서 실서버·키체인을 건드리지 않는다.
    @Test func testHostUsesMock() {
        #expect(AppConfig.usesMockRepositories)
        #expect(AppConfig.usesMockRepositories(environment: ["XCTestConfigurationFilePath": "/tmp/x.xctestconfiguration"]))
    }

    /// DEBUG 빌드에서는 `ECO_USE_MOCK=1`일 때만 Mock을 쓴다.
    @Test func mockSwitchFollowsEnvironment() {
        #expect(AppConfig.usesMockRepositories(environment: ["ECO_USE_MOCK": "1"]))
        #expect(!AppConfig.usesMockRepositories(environment: ["ECO_USE_MOCK": "0"]))
        #expect(!AppConfig.usesMockRepositories(environment: [:]))
    }
}
