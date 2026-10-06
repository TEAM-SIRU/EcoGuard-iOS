extension DIContainer {
    /// 로그인한 사용자(내 정보). 서버 주소가 있으면 `GET /users/me`, 없으면 Mock.
    var currentUserRepository: CurrentUserRepository {
        apiClient.map { CurrentUserRepositoryImpl(apiClient: $0) } ?? MockCurrentUserRepository()
    }
}
