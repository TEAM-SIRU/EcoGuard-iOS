import Foundation

/// 요청 하나. `requiresAuthorization`이면 `APIClient`가 액세스 토큰을 붙이고 401에 재발급을 시도한다.
nonisolated struct Endpoint: Sendable {
    enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case put = "PUT"
        case delete = "DELETE"
    }

    let method: Method
    let path: String
    let body: Data?
    /// `body`의 Content-Type. 바디가 없으면 보내지 않는다.
    let contentType: String
    let requiresAuthorization: Bool

    init(
        method: Method,
        path: String,
        body: Data? = nil,
        contentType: String = "application/json",
        requiresAuthorization: Bool = true
    ) {
        self.method = method
        self.path = path
        self.body = body
        self.contentType = contentType
        self.requiresAuthorization = requiresAuthorization
    }

    init(method: Method, path: String, json: some Encodable, requiresAuthorization: Bool = true) throws {
        self.init(
            method: method,
            path: path,
            body: try JSONEncoder().encode(json),
            requiresAuthorization: requiresAuthorization
        )
    }

    /// 바디를 완성된 `Data`로 들고 있어 401 재발급 뒤 다시 보낼 때도 같은 바디를 그대로 쓴다.
    init(method: Method, path: String, multipart: MultipartFormData, requiresAuthorization: Bool = true) {
        self.init(
            method: method,
            path: path,
            body: multipart.encoded(),
            contentType: multipart.contentType,
            requiresAuthorization: requiresAuthorization
        )
    }
}

/// 서버 계약: EcoGuard-Server `auth/AuthController.kt`.
nonisolated extension Endpoint {
    static func login(authCode: String) throws -> Endpoint {
        try Endpoint(method: .post, path: "/api/v1/auth/login", json: LoginRequestDTO(authCode: authCode), requiresAuthorization: false)
    }

    /// Authorization 헤더 없이 보낸다. 리프레시 토큰이 무효면 바디 없는 401.
    static func refresh(refreshToken: String) throws -> Endpoint {
        try Endpoint(method: .post, path: "/api/v1/auth/refresh", json: RefreshRequestDTO(refreshToken: refreshToken), requiresAuthorization: false)
    }

    /// 성공하면 바디 없는 200. 서버는 이 사용자의 기존 토큰을 모두 무효로 만든다(다른 기기 포함).
    static let logout = Endpoint(method: .post, path: "/api/v1/auth/logout")
}
