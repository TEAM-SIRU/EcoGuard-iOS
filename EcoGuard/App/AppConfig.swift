import Foundation

/// 빌드 설정에서 Info.plist로 주입한 앱 설정 값.
enum AppConfig {
    /// 교사용 웹 관리자 주소. 빌드 설정 `ECO_WEB_ADMIN_URL` → Info.plist `EcoWebAdminURL`.
    /// 주소가 정해지기 전까지 빈 값이며, 그동안 교사 안내 화면의 복사·공유 버튼은 숨긴다.
    static var webAdminURL: URL? {
        webAdminURL(from: Bundle.main.object(forInfoDictionaryKey: "EcoWebAdminURL") as? String)
    }

    /// 비어 있거나 http(s) 주소가 아니면 nil.
    static func webAdminURL(from rawValue: String?) -> URL? {
        guard
            let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
            !trimmed.isEmpty,
            let components = URLComponents(string: trimmed),
            let scheme = components.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            let host = components.host,
            !host.isEmpty
        else { return nil }
        return components.url
    }
}
