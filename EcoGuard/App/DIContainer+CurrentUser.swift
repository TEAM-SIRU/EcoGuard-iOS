extension DIContainer {
    /// 로그인한 사용자 요약(이름). 서버 주소가 있으면 로그인 때 저장한 값, 없으면 Mock.
    var currentUserRepository: CurrentUserRepository {
        apiClient.map { CurrentUserRepositoryImpl(authSession: $0.authSession) } ?? MockCurrentUserRepository()
    }
}
