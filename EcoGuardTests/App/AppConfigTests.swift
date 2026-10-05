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

    /// 클라이언트 ID나 리다이렉트 URI 빌드 설정이 비어 있으면(서버팀 값 수신 전) 설정이 없는 것으로 본다.
    @Test(arguments: [
        ("", "ecoguard://oauth/callback"),
        ("  ", "ecoguard://oauth/callback"),
        ("client-1", "://"),
        ("client-1", ""),
        ("client-1", "http://example.com/callback"),
        ("client-1", "ecoguard:callback")
    ])
    func incompleteOAuthSettingsAreIgnored(clientID: String, redirectURI: String) {
        #expect(AppConfig.gsmOAuthConfiguration(
            authorizeURL: Self.authorizeURL,
            clientID: clientID,
            redirectURI: redirectURI
        ) == nil)
    }

    @Test func emptyAuthorizeHostIsIgnored() {
        #expect(AppConfig.gsmOAuthConfiguration(
            authorizeURL: "https://",
            clientID: "client-1",
            redirectURI: "ecoguard://oauth/callback"
        ) == nil)
    }

    @Test func filledOAuthSettingsMakeConfiguration() throws {
        let configuration = try #require(AppConfig.gsmOAuthConfiguration(
            authorizeURL: Self.authorizeURL,
            clientID: " client-1 ",
            redirectURI: "ecoguard://oauth/callback"
        ))
        #expect(configuration.clientID == "client-1")
        #expect(configuration.redirectURI.absoluteString == "ecoguard://oauth/callback")
        #expect(configuration.callback == .customScheme("ecoguard"))
    }
}
