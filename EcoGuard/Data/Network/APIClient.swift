import Foundation

/// 인증이 필요한 요청에 액세스 토큰을 붙인다. 401이면 재발급 후 원래 요청을 한 번만 다시 보낸다.
nonisolated struct APIClient: Sendable {
    let httpClient: HTTPClient
    let authSession: AuthSession

    func send<Response: Decodable>(_ endpoint: Endpoint, as type: Response.Type = Response.self) async throws -> Response {
        let data = try await data(for: endpoint)
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    /// 응답 바디가 없는 요청.
    func send(_ endpoint: Endpoint) async throws {
        _ = try await data(for: endpoint)
    }

    private func data(for endpoint: Endpoint) async throws -> Data {
        guard endpoint.requiresAuthorization else {
            let (data, response) = try await httpClient.data(for: endpoint, accessToken: nil)
            return try HTTPClient.validate(data, response)
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
        return try HTTPClient.validate(data, response)
    }
}
