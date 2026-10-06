/// 서버 계약: EcoGuard-Server `cleaningarea/CleaningAreaController.kt`.
nonisolated extension Endpoint {
    /// 내 청소 구역. 배정되지 않았으면 404 `NO_ASSIGNMENT`.
    static let myAssignment = Endpoint(method: .get, path: "/api/v1/assignments/me")
}
