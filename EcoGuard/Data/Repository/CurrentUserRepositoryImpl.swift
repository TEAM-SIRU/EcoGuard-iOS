/// 서버 내 정보(`GET /users/me`). 받은 값은 토큰과 같이 `AuthSession`이 들고 있다가 지운다(로그아웃·세션 만료·탈퇴).
final class CurrentUserRepositoryImpl: CurrentUserRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchCurrentUser() async throws -> CurrentUser {
        let authSession = apiClient.authSession
        let generation = await authSession.sessionGeneration()
        do {
            let response: MyProfileResponseDTO = try await apiClient.send(.myProfile)
            await authSession.updateUser(response.sessionUser, startedIn: generation)
            return response.sessionUser.toDomain()
        } catch {
            // 이름·학번은 화면 보조 정보라 마지막으로 받은 값으로 보여 준다. 취소·세션 만료는 그대로 알린다.
            guard !Task.isCancelled, error as? APIError != .sessionExpired,
                  let cached = authSession.currentUser()
            else { throw error }
            return cached.toDomain()
        }
    }

    func withdraw() async throws {
        try await apiClient.send(.withdraw)
        // 서버가 토큰을 모두 무효로 만들었으므로 로그아웃처럼 기기 값을 지운다.
        await apiClient.authSession.clear()
    }
}
