import Foundation

/// 인증이 필요한 요청에 액세스 토큰을 붙인다. 401이면 재발급 후 원래 요청을 한 번만 다시 보낸다.
nonisolated struct APIClient: Sendable {
    let httpClient: HTTPClient
    let authSession: AuthSession

    func send<Response: Decodable>(_ endpoint: Endpoint, as type: Response.Type = Response.self) async throws -> Response {
        try Self.decode(Response.self, from: try await data(for: endpoint))
    }

    /// 응답 바디가 없는 요청.
    func send(_ endpoint: Endpoint) async throws {
        _ = try await data(for: endpoint)
    }

    /// 에러 바디의 `code` 말고 다른 필드도 읽어야 하는 요청. 2xx가 아니어도 던지지 않는다(401 재발급은 한다).
    /// 다 읽은 뒤 `HTTPClient.validate`·`decode`로 이어 간다.
    func response(for endpoint: Endpoint) async throws -> (Data, HTTPURLResponse) {
        guard endpoint.requiresAuthorization else {
            return try await httpClient.data(for: endpoint, accessToken: nil)
        }
        var accessToken = await authSession.accessToken()
        if accessToken == nil {
            accessToken = try await authSession.validAccessToken(replacing: nil)
        }
        var (data, response) = try await httpClient.data(for: endpoint, accessToken: accessToken)
        if response.statusCode == 401 {
            let refreshed = try await authSession.validAccessToken(replacing: accessToken)
            (data, response) = try await httpClient.data(for: endpoint, accessToken: refreshed)
            // 새 토큰으로도 401이면 더 재발급하지 않는다(무한 반복 방지). `validate`가 `.unauthorized`를 던진다.
        }
        return (data, response)
    }

    static func decode<Response: Decodable>(_ type: Response.Type, from data: Data) throws -> Response {
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    private func data(for endpoint: Endpoint) async throws -> Data {
        let (data, response) = try await response(for: endpoint)
        return try HTTPClient.validate(data, response)
    }
}
