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
}
