import Foundation

/// 서버 내 정보(`GET /users/me`). 받은 값은 토큰과 같이 `AuthSession`이 들고 있다가 지운다(로그아웃·세션 만료·탈퇴).
final class CurrentUserRepositoryImpl: CurrentUserRepository {
    private let apiClient: APIClient
    /// 탈퇴 요청을 보냈지만 응답을 받지 못했다(서버에 닿았을 수 있다). 같은 저장소로 다시 탈퇴할 때 쓴다.
    private var mayHaveWithdrawn = false

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
        do {
            try await apiClient.send(.withdraw)
            mayHaveWithdrawn = false
        } catch APIError.sessionExpired where mayHaveWithdrawn {
            // 앞선 탈퇴 요청이 응답 없이 끝나(네트워크 오류·타임아웃) 서버에 닿았을 수 있다. 닿았으면 서버가 토큰을 모두 무효로 만들어
            // 다시 보낸 요청과 재발급이 401이 된다. 계정을 되살릴 방법이 없으므로 탈퇴한 것으로 보고 정리한다.
            // 그 밖의 세션 만료(리프레시 토큰 만료 등)는 계정이 남아 있으므로 그대로 알린다(다시 로그인해 탈퇴).
            mayHaveWithdrawn = false
        } catch let error as URLError {
            // 응답을 받지 못했다. 서버는 처리했을 수 있다.
            mayHaveWithdrawn = true
            throw error
        }
        // 서버가 토큰을 모두 무효로 만들었으므로 로그아웃처럼 기기 값을 지운다.
        await apiClient.authSession.clear()
    }
}
