import Foundation
import os
@testable import EcoGuard

/// 테스트마다 다른 응답을 주는 URLProtocol 스텁. 세션 헤더의 id로 핸들러를 찾아 테스트끼리 병렬로 돌아도 섞이지 않는다.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) async throws -> (Int, Data)

    private static let idHeader = "X-Stub-ID"
    private static let handlers = OSAllocatedUnfairLock<[String: Handler]>(initialState: [:])
    private var loadingTask: Task<Void, Never>?

    /// 핸들러를 등록하고 그 핸들러로만 응답하는 세션을 만든다.
    static func makeSession(handler: @escaping Handler) -> URLSession {
        let id = UUID().uuidString
        handlers.withLock { $0[id] = handler }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpAdditionalHeaders = [idHeader: id]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let request = request
        guard let id = request.value(forHTTPHeaderField: Self.idHeader),
              let handler = Self.handlers.withLock({ $0[id] })
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        loadingTask = Task { [weak self] in
            do {
                let (statusCode, data) = try await handler(request)
                guard let self, let url = request.url,
                      let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)
                else { return }
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                guard let self else { return }
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {
        loadingTask?.cancel()
    }
}

extension URLRequest {
    /// URLProtocol에서는 `httpBody`가 스트림으로 바뀌어 있다.
    var bodyData: Data? {
        if let httpBody { return httpBody }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }

    var bearerToken: String? {
        value(forHTTPHeaderField: "Authorization").map { String($0.dropFirst("Bearer ".count)) }
    }
}

/// 테스트용 인메모리 토큰 저장소.
final class InMemoryTokenStore: TokenStore {
    private let tokens: OSAllocatedUnfairLock<AuthTokens?>

    init(_ tokens: AuthTokens? = nil) {
        self.tokens = OSAllocatedUnfairLock(initialState: tokens)
    }

    var current: AuthTokens? { tokens.withLock { $0 } }

    func load() -> AuthTokens? { current }
    func save(_ newTokens: AuthTokens) throws { tokens.withLock { $0 = newTokens } }
    func clear() { tokens.withLock { $0 = nil } }
}

/// 서버 호출 기록.
final class RequestLog: Sendable {
    private let entries = OSAllocatedUnfairLock<[URLRequest]>(initialState: [])

    func append(_ request: URLRequest) { entries.withLock { $0.append(request) } }
    var requests: [URLRequest] { entries.withLock { $0 } }

    func requests(path: String) -> [URLRequest] {
        requests.filter { $0.url?.path() == path }
    }
}
