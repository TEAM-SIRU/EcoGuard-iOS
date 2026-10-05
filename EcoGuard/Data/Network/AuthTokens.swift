/// 서버가 발급한 토큰 쌍. 리프레시할 때마다 둘 다 바뀐다(액세스 2시간, 리프레시 7일 회전).
nonisolated struct AuthTokens: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
}
