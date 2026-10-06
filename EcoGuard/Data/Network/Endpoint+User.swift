/// 서버 계약: EcoGuard-Server `user/UserController.kt`.
nonisolated extension Endpoint {
    /// 내 정보(이름·학번·학년·반).
    static let myProfile = Endpoint(method: .get, path: "/api/v1/users/me")

    /// 회원 탈퇴(학생). 성공하면 바디 없는 200이고 서버는 이 사용자의 토큰을 모두 무효로 만든다.
    static let withdraw = Endpoint(method: .delete, path: "/api/v1/users/me")
}
