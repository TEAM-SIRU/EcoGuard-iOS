import Foundation

/// 로그인한 사용자(저장 형식). 로그인 응답으로 처음 저장하고 `GET /users/me`를 받을 때마다 바꾼다(`CurrentUserRepositoryImpl`).
/// 로그인 응답에는 학번·학년·반이 없어 내 정보를 받기 전까지 nil이다. 이전 버전이 저장한 값(이름만)도 그대로 읽힌다.
nonisolated struct SessionUser: Codable, Equatable, Sendable {
    let userId: Int64
    let name: String
    var studentNumber: String?
    var grade: Int?
    var classNo: Int?
}

/// 로그인한 사용자 요약 보관. 토큰과 같이 `AuthSession`이 지운다(로그아웃·세션 만료·교사 로그인). 재설치하면 UserDefaults째 지워진다.
nonisolated protocol SessionUserStore: Sendable {
    func load() -> SessionUser?
    func save(_ user: SessionUser)
    func clear()
}

/// UserDefaults는 스레드 안전하다.
nonisolated final class UserDefaultsSessionUserStore: SessionUserStore, @unchecked Sendable {
    /// 로그인한 사용자에 딸린 기기 저장 값. 다른 사용자에게 남지 않게 사용자 요약과 같이 지운다.
    static let sessionScopedKeys = [HomeRepositoryImpl.dismissedNoticeIDsKey]

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
        for key in Self.sessionScopedKeys {
            defaults.removeObject(forKey: key)
        }
    }
}
