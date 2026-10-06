protocol CurrentUserRepository {
    /// 로그인할 때 저장한 사용자. 로그아웃·세션 만료 뒤나 이 기능 전에 로그인해 둔 세션이면 nil.
    func currentUser() -> CurrentUser?
}
