import Foundation

/// 서버 계약: EcoGuard-Server `activity/ActivityController.kt`. 학생만 부를 수 있다.
nonisolated extension Endpoint {
    static func myActivity(year: Int, month: Int) -> Endpoint {
        Endpoint(
            method: .get,
            path: "/api/v1/service-times/me",
            queryItems: [URLQueryItem(name: "year", value: String(year)), URLQueryItem(name: "month", value: String(month))]
        )
    }

    /// 이번 주(월~금) 청소 현황.
    static let myWeeklyActivity = Endpoint(method: .get, path: "/api/v1/service-times/me/weekly")
}
