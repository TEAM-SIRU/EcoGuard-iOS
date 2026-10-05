import Foundation

/// 로그인 응답의 사용자 요약(저장 형식). 내 정보 API가 없어 이름을 여기서 쓴다(`CurrentUserRepositoryImpl`).
nonisolated struct SessionUser: Codable, Equatable, Sendable {
    let userId: Int64
    let name: String
}

/// 로그인한 사용자 요약 보관. 토큰과 같이 `AuthSession`이 지운다(로그아웃·세션 만료). 재설치하면 UserDefaults째 지워진다.
nonisolated protocol SessionUserStore: Sendable {
    func load() -> SessionUser?
    func save(_ user: SessionUser)
    func clear()
}

/// UserDefaults는 스레드 안전하다.
nonisolated final class UserDefaultsSessionUserStore: SessionUserStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "auth.sessionUser") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> SessionUser? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(SessionUser.self, from: $0) }
    }

    func save(_ user: SessionUser) {
        defaults.set(try? JSONEncoder().encode(user), forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
