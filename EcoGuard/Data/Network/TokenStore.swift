import Foundation
import Security

/// 토큰 저장소. 앱은 키체인을 쓰고 테스트는 인메모리 구현을 쓴다.
nonisolated protocol TokenStore: Sendable {
    func load() -> AuthTokens?
    func save(_ tokens: AuthTokens) throws
    func clear()
}

/// 토큰 쌍을 키체인 항목 하나(JSON)로 저장한다. 두 토큰이 따로 바뀌는 중간 상태가 남지 않는다.
nonisolated struct KeychainTokenStore: TokenStore {
    struct KeychainError: Error {
        let status: OSStatus
    }

    private let service: String
    private let account: String

    init(service: String = "team.siru.EcoGuard.auth", account: String = "tokens") {
        self.service = service
        self.account = account
    }

    func load() -> AuthTokens? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return try? JSONDecoder().decode(AuthTokens.self, from: data)
    }

    func save(_ tokens: AuthTokens) throws {
        let data = try JSONEncoder().encode(tokens)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            // 백그라운드 갱신에서도 읽을 수 있게 첫 잠금 해제 이후로 두고, 백업·다른 기기로는 옮기지 않는다.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let addStatus = SecItemAdd(baseQuery.merging(attributes) { $1 } as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
        } else if status != errSecSuccess {
            throw KeychainError(status: status)
        }
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
