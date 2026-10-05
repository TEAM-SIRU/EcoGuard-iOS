import Foundation

/// 네트워크 공통 에러. 전송 실패(오프라인, 취소)는 `URLError` 그대로 올라간다.
nonisolated enum APIError: Error, Equatable {
    /// 토큰을 재발급해 다시 보냈는데도 401이다. 세션은 지우지 않는다.
    case unauthorized
    /// 리프레시 토큰이 없거나 무효다. 토큰을 지웠고 로그인 화면으로 가야 한다.
    case sessionExpired
    /// 2xx가 아닌 응답. `code`는 서버 `ErrorResponse.code`(바디가 없으면 nil).
    case server(statusCode: Int, code: String?)
    case invalidResponse
    case decoding
}

/// Base URL에 요청을 보내고 응답을 그대로 돌려준다. 토큰 재발급은 모른다.
nonisolated struct HTTPClient: Sendable {
    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func data(for endpoint: Endpoint, accessToken: String?) async throws -> (Data, HTTPURLResponse) {
        var url = baseURL.appending(path: endpoint.path)
        if !endpoint.queryItems.isEmpty {
            url.append(queryItems: endpoint.queryItems)
        }
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body = endpoint.body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        return (data, httpResponse)
    }

    /// 2xx면 바디를, 아니면 `APIError`를 던진다.
    static func validate(_ data: Data, _ response: HTTPURLResponse) throws -> Data {
        guard !(200..<300).contains(response.statusCode) else { return data }
        if let error = try? JSONDecoder().decode(ErrorResponseDTO.self, from: data) {
            throw APIError.server(statusCode: response.statusCode, code: error.code)
        }
        if response.statusCode == 401 {
            throw APIError.unauthorized
        }
        throw APIError.server(statusCode: response.statusCode, code: nil)
    }
}
