import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct VerificationRepositoryImplTests {
    private nonisolated static let path = "/api/v1/verifications"
    private nonisolated static let mePath = "/api/v1/verifications/me"
    private static let tokens = AuthTokens(accessToken: "access", refreshToken: "refresh")
    /// 2026-09-29 08:04 KST.
    private static let now = Date(timeIntervalSince1970: 1_790_636_640)

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

    /// 내 인증 목록. `todayStatus`가 있으면 오늘(2026-09-29) 항목을 넣는다.
    private nonisolated static func meJSON(todayStatus: String?) -> Data {
        let yesterday = #"{"verificationId":6,"photoUrl":"/a.jpg","date":"2026-09-28","areaName":"A","reviewStatus":"APPROVED","failReasons":null}"#
        let today = todayStatus.map {
            #"{"verificationId":7,"photoUrl":"/b.jpg","date":"2026-09-29","areaName":"A","reviewStatus":"\#($0)","failReasons":null}"#
        }
        return Data("[\([today, yesterday].compactMap { $0 }.joined(separator: ","))]".utf8)
    }

    /// 업로드는 `upload`가, 내 인증 목록은 `todayStatus`로 응답한다.
    private nonisolated static func handler(
        log: RequestLog,
        todayStatus: String? = "PROCESSING",
        upload: @escaping @Sendable (Int) throws -> (Int, Data)
    ) -> StubURLProtocol.Handler {
        { request in
            log.append(request)
            if request.url?.path() == mePath { return (200, meJSON(todayStatus: todayStatus)) }
            return try upload(log.requests(path: path).count)
        }
    }

    @Test func submitSendsMultipartPhotoAndReturnsServerID() async throws {
        let log = RequestLog()
        let repository = Self.makeRepository { request in
            log.append(request)
            return (201, Self.createdJSON)
        }
        let photo = Self.photo()

        let submission = try await repository.submit(photo)

        #expect(submission == VerificationSubmission(id: "7", submittedAt: Self.now))
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

    /// 제출 시각은 서버가 주지 않아 비우고, 오늘 인증의 검수 상태를 싣는다.
    @Test(arguments: [
        ("PROCESSING", VerificationResult.Status.processing),
        ("APPROVED", .approved),
        ("REJECTED", .rejected),
        ("MANUAL_REVIEW", .manualReview)
    ])
    func alreadySubmittedTodayCarriesTodayStatus(raw: String, status: VerificationResult.Status) async throws {
        let log = RequestLog()
        let repository = Self.makeRepository(handler: Self.handler(log: log, todayStatus: raw) { _ in
            (409, Self.errorJSON("ALREADY_SUBMITTED_TODAY"))
        })

        await #expect(throws: VerificationError.alreadySubmitted(submittedAt: nil, status: status)) {
            try await repository.submit(Self.photo())
        }
        #expect(log.requests(path: Self.mePath).map(\.httpMethod) == ["GET"])
    }

    /// 목록에 오늘 항목이 없거나 목록 조회가 실패하면 상태도 비운다.
    @Test(arguments: [false, true])
    func alreadySubmittedWithoutTodayStatus(listFails: Bool) async throws {
        let repository = Self.makeRepository { request in
            if request.url?.path() == Self.mePath {
                return listFails ? (500, Data()) : (200, Self.meJSON(todayStatus: nil))
            }
            return (409, Self.errorJSON("ALREADY_SUBMITTED_TODAY"))
        }

        await #expect(throws: VerificationError.alreadySubmitted(submittedAt: nil, status: nil)) {
            try await repository.submit(Self.photo())
        }
    }

    /// 응답을 받지 못한 사진을 다시 보냈는데 `오늘 이미 제출`이면 앞선 전송이 접수된 것이다. 제출 시각은 처음 보낸 시각.
    @Test(arguments: [0, 500])
    func retryOfUnconfirmedPhotoTreatsAlreadySubmittedAsAccepted(firstStatus: Int) async throws {
        let log = RequestLog()
        let repository = Self.makeRepository(handler: Self.handler(log: log) { attempt in
            if attempt == 1 {
                guard firstStatus != 0 else { throw URLError(.networkConnectionLost) }
                return (firstStatus, Self.errorJSON("INTERNAL_SERVER_ERROR"))
            }
            return (409, Self.errorJSON("ALREADY_SUBMITTED_TODAY"))
        })
        let photo = Self.photo()

        await #expect(throws: (any Error).self) {
            try await repository.submit(photo)
        }
        let submission = try await repository.submit(photo)

        #expect(submission == VerificationSubmission(id: "7", submittedAt: Self.now))
        #expect(log.requests(path: Self.path).count == 2)
    }

    /// 서버가 거절(4xx)한 사진은 접수되지 않은 것이 확실하다. 다시 보내 `오늘 이미 제출`이면 다른 제출이 있는 것이라 성공으로 보지 않는다.
    @Test(arguments: [(400, "INVALID_IMAGE"), (403, "NOT_ASSIGNED_AREA"), (404, "NO_ASSIGNMENT")])
    func retryAfterServerRejectionIsNotFalseSuccess(statusCode: Int, code: String) async throws {
        let log = RequestLog()
        let repository = Self.makeRepository(handler: Self.handler(log: log) { attempt in
            attempt == 1 ? (statusCode, Self.errorJSON(code)) : (409, Self.errorJSON("ALREADY_SUBMITTED_TODAY"))
        })
        let photo = Self.photo()

        await #expect(throws: APIError.server(statusCode: statusCode, code: code)) {
            try await repository.submit(photo)
        }
        await #expect(throws: VerificationError.alreadySubmitted(submittedAt: nil, status: .processing)) {
            try await repository.submit(photo)
        }
    }

    /// 마감으로 거절된 사진도 접수되지 않았다.
    @Test func retryAfterDeadlineRejectionIsNotFalseSuccess() async throws {
        let log = RequestLog()
        let repository = Self.makeRepository(handler: Self.handler(log: log) { attempt in
            attempt == 1 ? (403, Self.errorJSON("OUT_OF_CERTIFICATION_TIME")) : (409, Self.errorJSON("ALREADY_SUBMITTED_TODAY"))
        })
        let photo = Self.photo()

        await #expect(throws: VerificationError.deadlinePassed) {
            try await repository.submit(photo)
        }
        await #expect(throws: VerificationError.alreadySubmitted(submittedAt: nil, status: .processing)) {
            try await repository.submit(photo)
        }
    }

    /// 다른 사진이면 앞선 사진의 전송 실패와 상관없이 이미 제출로 본다.
    @Test func otherPhotoAfterFailureStillAlreadySubmitted() async throws {
        let log = RequestLog()
        let repository = Self.makeRepository(handler: Self.handler(log: log) { attempt in
            if attempt == 1 { throw URLError(.networkConnectionLost) }
            return (409, Self.errorJSON("ALREADY_SUBMITTED_TODAY"))
        })

        await #expect(throws: URLError.self) {
            try await repository.submit(Self.photo())
        }
        await #expect(throws: VerificationError.alreadySubmitted(submittedAt: nil, status: .processing)) {
            try await repository.submit(Self.photo())
        }
    }

    /// 마감 시각은 서버에 없어 비우고, 구역·인증 시간은 Mock에서 가져온다.
    @Test func fetchSessionIsOpenWithoutDeadlineWhenNothingToday() async throws {
        let log = RequestLog()
        let repository = Self.makeRepository(handler: Self.handler(log: log, todayStatus: nil) { _ in (500, Data()) })

        let session = try await repository.fetchSession()

        #expect(session.availability == .open(deadline: nil))
        #expect(session.area == MockVerificationRepository.Fixture.area)
        #expect(session.window == MockVerificationRepository.Fixture.window)
        #expect(session.serverNow == Self.now)
    }

    @Test func fetchSessionReportsTodaySubmission() async throws {
        let log = RequestLog()
        let repository = Self.makeRepository(handler: Self.handler(log: log, todayStatus: "APPROVED") { _ in (500, Data()) })

        let session = try await repository.fetchSession()

        #expect(session.availability == .alreadySubmitted(submittedAt: nil, status: .approved))
    }
}
