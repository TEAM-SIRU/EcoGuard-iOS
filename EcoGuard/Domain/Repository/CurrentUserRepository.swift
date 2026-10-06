protocol CurrentUserRepository {
    /// 서버의 내 정보. 받아 오지 못하면 마지막으로 받은 값(로그인 때 저장한 값 포함)을 쓰고, 그것도 없으면 에러를 던진다.
    func fetchCurrentUser() async throws -> CurrentUser
    /// 회원 탈퇴. 성공하면 기기의 토큰과 사용자 정보를 지운다. 실패하면 계정이 남아 있으므로 지우지 않는다.
    func withdraw() async throws
}
