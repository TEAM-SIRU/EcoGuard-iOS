import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct VerificationRepositoryImplTests {
    private static let path = "/api/v1/verifications"
    private static let tokens = AuthTokens(accessToken: "access", refreshToken: "refresh")
    private static let now = Date(timeIntervalSince1970: 1_790_000_000)

    private static func makeRepository(
        store: InMemoryTokenStore = InMemoryTokenStore(tokens),
        handler: @escaping StubURLProtocol.Handler
    ) -> VerificationRepositoryImpl {
        let httpClient = HTTPClient(
            baseURL: URL(string: "https://api.example.com")!,
            session: StubURLProtocol.makeSession(handler: handler)
        )
        return VerificationRepositoryImpl(
            apiClient: APIClient(httpClient: httpClient, authSession: AuthSession(tokenStore: store, httpClient: httpClient)),
            sessionSource: MockVerificationRepository(delay: .zero),
            now: { now }
        )
    }

    private static func photo(_ bytes: [UInt8] = [0xFF, 0xD8, 0x01, 0xFF, 0xD9]) -> VerificationPhoto {
        VerificationPhoto(id: UUID(), jpegData: Data(bytes), capturedAt: now)
    }

    private nonisolated static func errorJSON(_ code: String) -> Data {
        Data(#"{"code":"\#(code)","message":"m"}"#.utf8)
    }

    private nonisolated static let createdJSON = Data(#"{"verificationId":7,"status":"PROCESSING"}"#.utf8)

    @Test func submitSendsMultipartPhoto() async throws {
        let log = RequestLog()
        let repository = Self.makeRepository { request in
            log.append(request)
            return (201, Self.createdJSON)
        }
        let photo = Self.photo()

        let submission = try await repository.submit(photo)

        #expect(submission == VerificationSubmission(submittedAt: Self.now))
        let request = try #require(log.requests(path: Self.path).first)
        #expect(request.httpMethod == "POST")
        #expect(request.bearerToken == "access")
        let contentType = try #require(request.value(forHTTPHeaderField: "Content-Type"))
        #expect(contentType.hasPrefix("multipart/form-data; boundary="))
        let boundary = String(contentType.dropFirst("multipart/form-data; boundary=".count))
        var expected = Data((
            "--\(boundary)\r\n"
            + "Content-Disposition: form-data; name=\"photo\"; filename=\"\(photo.id.uuidString).jpg\"\r\n"
            + "Content-Type: image/jpeg\r\n\r\n"
        ).utf8)
        expected.append(photo.jpegData)
        expected.append(Data("\r\n--\(boundary)--\r\n".utf8))
        #expect(request.bodyData == expected)
    }

    /// 토큰 재발급 뒤 다시 보낼 때도 같은 사진 바디를 그대로 보낸다.
    @Test func retryAfterRefreshResendsSameBody() async throws {
        let log = RequestLog()
        let repository = Self.makeRepository { request in
            log.append(request)
            if request.url?.path() == "/api/v1/auth/refresh" {
                return (200, Data(#"{"accessToken":"access-new","refreshToken":"refresh-new"}"#.utf8))
            }
            return request.bearerToken == "access-new" ? (201, Self.createdJSON) : (401, Data())
        }

        _ = try await repository.submit(Self.photo())

        let uploads = log.requests(path: Self.path)
        #expect(uploads.map(\.bearerToken) == ["access", "access-new"])
        let bodies = uploads.map(\.bodyData)
        #expect(bodies[0] != nil && bodies[0] == bodies[1])
        #expect(uploads[0].value(forHTTPHeaderField: "Content-Type") == uploads[1].value(forHTTPHeaderField: "Content-Type"))
    }

    /// 인증 시간 밖·주말·방학(서버 #15)이 모두 같은 코드로 온다.
    @Test func outOfCertificationTimeMapsToDeadlinePassed() async throws {
        let repository = Self.makeRepository { _ in (403, Self.errorJSON("OUT_OF_CERTIFICATION_TIME")) }

        await #expect(throws: VerificationError.deadlinePassed) {
            try await repository.submit(Self.photo())
        }
    }

    @Test func alreadySubmittedTodayMapsToAlreadySubmitted() async throws {
        let repository = Self.makeRepository { _ in (409, Self.errorJSON("ALREADY_SUBMITTED_TODAY")) }

        await #expect(throws: VerificationError.alreadySubmitted(submittedAt: Self.now)) {
            try await repository.submit(Self.photo())
        }
    }

    /// 응답을 받지 못한 사진을 다시 보냈는데 `오늘 이미 제출`이면 앞선 전송이 접수된 것이다.
    @Test func retryOfUnconfirmedPhotoTreatsAlreadySubmittedAsAccepted() async throws {
        let attempts = RequestLog()
        let repository = Self.makeRepository { request in
            attempts.append(request)
            if attempts.requests.count == 1 { throw URLError(.networkConnectionLost) }
            return (409, Self.errorJSON("ALREADY_SUBMITTED_TODAY"))
        }
        let photo = Self.photo()

        await #expect(throws: URLError.self) {
            try await repository.submit(photo)
        }
        let submission = try await repository.submit(photo)

        #expect(submission == VerificationSubmission(submittedAt: Self.now))
        #expect(attempts.requests.count == 2)
    }

    /// 다른 사진이면 앞선 사진의 전송 실패와 상관없이 이미 제출로 본다.
    @Test func otherPhotoAfterFailureStillAlreadySubmitted() async throws {
        let attempts = RequestLog()
        let repository = Self.makeRepository { request in
            attempts.append(request)
            if attempts.requests.count == 1 { throw URLError(.networkConnectionLost) }
            return (409, Self.errorJSON("ALREADY_SUBMITTED_TODAY"))
        }

        await #expect(throws: URLError.self) {
            try await repository.submit(Self.photo())
        }
        await #expect(throws: VerificationError.alreadySubmitted(submittedAt: Self.now)) {
            try await repository.submit(Self.photo())
        }
    }

    @Test(arguments: ["NO_ASSIGNMENT", "INVALID_IMAGE", "NOT_ASSIGNED_AREA"])
    func otherServerErrorsPassThrough(code: String) async throws {
        let repository = Self.makeRepository { _ in (code == "NO_ASSIGNMENT" ? 404 : 400, Self.errorJSON(code)) }

        do {
            _ = try await repository.submit(Self.photo())
            Issue.record("에러가 나야 한다")
        } catch let error as APIError {
            guard case .server(_, code?) = error else {
                Issue.record("\(error)")
                return
            }
        }
    }
}
