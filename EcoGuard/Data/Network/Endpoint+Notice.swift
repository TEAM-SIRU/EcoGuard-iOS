/// 서버 계약: EcoGuard-Server `notice/NoticeController.kt`.
nonisolated extension Endpoint {
    static let notices = Endpoint(method: .get, path: "/api/v1/notices")

    /// 없는 공지면 404 `NOTICE_NOT_FOUND`.
    static func notice(id: Int64) -> Endpoint {
        Endpoint(method: .get, path: "/api/v1/notices/\(id)")
    }
}
