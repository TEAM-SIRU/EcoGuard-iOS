import Foundation
import Testing
@testable import EcoGuard

struct AppConfigTests {
    /// 이 값들이면 교사 안내 화면의 복사·공유 버튼을 숨긴다.
    @Test(arguments: [
        nil,
        "",
        "   ",
        "$(ECO_WEB_ADMIN_URL)",
        "admin.ecoguard",
        "ftp://example.com",
        "https://",
        "javascript:alert(1)"
    ] as [String?])
    func invalidValueHidesWebLinkActions(rawValue: String?) {
        #expect(AppConfig.webAdminURL(from: rawValue) == nil)
    }

    /// 예시 주소는 테스트에서만 쓴다(example.com은 문서용 예약 도메인).
    @Test(arguments: ["https://example.com", "http://example.com/admin", "  https://example.com/  "])
    func validValueShowsWebLinkActions(rawValue: String) {
        let url = AppConfig.webAdminURL(from: rawValue)
        #expect(url?.host() == "example.com")
    }

    /// 지금은 주소가 정해지지 않아 빌드 설정이 비어 있다.
    @Test func bundledValueIsEmptyUntilDecided() {
        #expect(AppConfig.webAdminURL == nil)
    }
}
