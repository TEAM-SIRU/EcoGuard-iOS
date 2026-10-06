import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct VerificationRepositoryImplTests {
    private nonisolated static let path = "/api/v1/verifications"
    private nonisolated static let todayPath = "/api/v1/verifications/today"
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
            now: { now }
        )
    }

    /// `uploadStartedAt`이 있으면 VM이 한 번 보내기 시작한 사진이다.
    private static func photo(uploadStartedAt: Date? = now, _ bytes: [UInt8] = [0xFF, 0xD8, 0x01, 0xFF, 0xD9]) -> VerificationPhoto {
        VerificationPhoto(id: UUID(), jpegData: Data(bytes), capturedAt: now, uploadStartedAt: uploadStartedAt)
    }

    private nonisolated static func errorJSON(_ code: String, submittedAt: String? = nil) -> Data {
        let extra = submittedAt.map { #","submittedAt":"\#($0)""# } ?? ""
        return Data(#"{"code":"\#(code)","message":"m"\#(extra)}"#.utf8)
    }

    private nonisolated static let createdJSON = Data(#"{"verificationId":7,"status":"PROCESSING","submittedAt":"2026-09-29T08:04:30.123456"}"#.utf8)

    /// 오늘 인증 정보. 서버 시각 2026-09-29 08:00:00, 인증 시간 07:20~08:10.
    private nonisolated static func todayJSON(
        canSubmit: Bool = true,
        reason: String? = nil,
        submitted: Bool = false,
        status: String? = nil,
        submittedAt: String? = nil
    ) -> Data {
        func json(_ value: String?) -> String { value.map { "\"\($0)\"" } ?? "null" }
        return Data("""
        {"serverTime":"2026-09-29T08:00:00.5","areaId":3,"areaName":"본관 2층 복도 A","cleanTime":"07:20~08:10",\
        "startTime":"07:20:00","endTime":"08:10:00","canSubmit":\(canSubmit),"unavailableReason":\(json(reason)),\
        "submitted":\(submitted),"verificationId":\(submitted ? "7" : "null"),"status":\(json(status)),"submittedAt":\(json(submittedAt))}
        """.utf8)
    }

    private static func kst(_ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar.date(from: DateComponents(year: 2026, month: 9, day: 29, hour: hour, minute: minute, second: second))!
    }

    // MARK: - 오늘 인증 정보

    @Test func fetchSessionOpenUsesServerTimeAndDeadline() async throws {
        let log = RequestLog()
        let repository = Self.makeRepository { request in
            log.append(request)
            return (200, Self.todayJSON())
        }

        let session = try await repository.fetchSession()

        #expect(session.area == "본관 2층 복도 A")
        #expect(session.window == CleaningWindow(startMinute: 7 * 60 + 20, endMinute: 8 * 60 + 10))
        #expect(session.serverNow == Self.kst(8, 0))
        #expect(session.availability == .open(deadline: Self.kst(8, 10)))
        #expect(log.requests(path: Self.todayPath).map(\.httpMethod) == ["GET"])
    }

    @Test(arguments: [
        ("WEEKEND", VerificationClosedReason.weekend),
        ("VACATION", .vacation),
        ("BEFORE_START", .outsideHours),
        ("AFTER_END", .outsideHours),
        // 앱이 모르는 사유도 화면을 띄운다.
        ("HOLIDAY", .outsideHours)
    ])
    func fetchSessionMapsUnavailableReason(raw: String, reason: VerificationClosedReason) async throws {
        let repository = Self.makeRepository { _ in (200, Self.todayJSON(canSubmit: false, reason: raw)) }

        let session = try await repository.fetchSession()

        #expect(session.availability == .outsideWindow(reason))
    }

    @Test(arguments: [
        ("PROCESSING", VerificationResult.Status?.some(.processing)),
        ("APPROVED", .approved),
        ("REJECTED", .rejected),
        ("MANUAL_REVIEW", .manualReview),
        ("UNKNOWN", nil)
    ])
    func fetchSessionReportsTodaySubmission(raw: String, status: VerificationResult.Status?) async throws {
        let repository = Self.makeRepository { _ in
            (200, Self.todayJSON(canSubmit: false, reason: "ALREADY_SUBMITTED", submitted: true, status: raw, submittedAt: "2026-09-29T07:41:05.1"))
        }

        let session = try await repository.fetchSession()

        #expect(session.availability == .alreadySubmitted(submittedAt: Self.kst(7, 41, 5), status: status))
    }

    @Test func fetchSessionPropagatesNoAssignment() async throws {
        let repository = Self.makeRepository { _ in (404, Self.errorJSON("NO_ASSIGNMENT")) }

        await #expect(throws: APIError.server(statusCode: 404, code: "NO_ASSIGNMENT")) {
            try await repository.fetchSession()
        }
    }

    // MARK: - 제출

    @Test func submitSendsMultipartPhotoWithRetryHeaders() async throws {
        let log = RequestLog()
        let repository = Self.makeRepository { request in
            log.append(request)
            return (201, Self.createdJSON)
        }
        let photo = Self.photo(uploadStartedAt: Self.kst(8, 9, 58))

        let submission = try await repository.submit(photo)

        #expect(submission == VerificationSubmission(id: "7", submittedAt: Self.kst(8, 4, 30)))
        let request = try #require(log.requests(path: Self.path).first)
        #expect(request.httpMethod == "POST")
        #expect(request.bearerToken == "access")
        #expect(request.value(forHTTPHeaderField: "Idempotency-Key") == photo.id.uuidString)
        #expect(request.value(forHTTPHeaderField: "X-Submit-Started-At") == "2026-09-29T08:09:58+09:00")
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

    /// 보내기 시작한 시각이 없으면(직접 호출) 지금 시각을 보낸다.
    @Test func submitWithoutStartedAtSendsNow() async throws {
        let log = RequestLog()
        let repository = Self.makeRepository { request in
            log.append(request)
            return (201, Self.createdJSON)
        }

        _ = try await repository.submit(Self.photo(uploadStartedAt: nil))

        #expect(log.requests(path: Self.path).first?.value(forHTTPHeaderField: "X-Submit-Started-At") == "2026-09-29T08:04:00+09:00")
    }

    /// 응답을 못 받아 같은 사진을 다시 보내면 같은 재전송 키·시작 시각을 보낸다. 서버는 처음 접수 결과를 돌려준다.
    @Test(arguments: [0, 500])
    func resendOfSamePhotoUsesSameKeyAndStartedAt(firstStatus: Int) async throws {
        let log = RequestLog()
        let repository = Self.makeRepository { request in
            log.append(request)
            if log.requests(path: Self.path).count == 1 {
                guard firstStatus != 0 else { throw URLError(.networkConnectionLost) }
                return (firstStatus, Self.errorJSON("INTERNAL_SERVER_ERROR"))
            }
            return (201, Self.createdJSON)
        }
        let photo = Self.photo(uploadStartedAt: Self.kst(8, 9, 58))

        await #expect(throws: (any Error).self) {
            try await repository.submit(photo)
        }
        let submission = try await repository.submit(photo)

        #expect(submission == VerificationSubmission(id: "7", submittedAt: Self.kst(8, 4, 30)))
        let uploads = log.requests(path: Self.path)
        #expect(uploads.count == 2)
        #expect(Set(uploads.map { $0.value(forHTTPHeaderField: "Idempotency-Key") }) == [photo.id.uuidString])
        #expect(Set(uploads.map { $0.value(forHTTPHeaderField: "X-Submit-Started-At") }) == ["2026-09-29T08:09:58+09:00"])
    }

    /// 다른 사진은 다른 재전송 키로 보낸다.
    @Test func differentPhotosUseDifferentKeys() async throws {
        let log = RequestLog()
        let repository = Self.makeRepository { request in
            log.append(request)
            return (201, Self.createdJSON)
        }

        _ = try await repository.submit(Self.photo())
        _ = try await repository.submit(Self.photo())

        let keys = log.requests(path: Self.path).compactMap { $0.value(forHTTPHeaderField: "Idempotency-Key") }
        #expect(keys.count == 2 && keys[0] != keys[1])
    }

    /// 토큰 재발급 뒤 다시 보낼 때도 같은 사진 바디와 재전송 헤더를 그대로 보낸다.
    @Test func retryAfterRefreshResendsSameBodyAndHeaders() async throws {
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
        for field in ["Content-Type", "Idempotency-Key", "X-Submit-Started-At"] {
            #expect(uploads[0].value(forHTTPHeaderField: field) != nil)
            #expect(uploads[0].value(forHTTPHeaderField: field) == uploads[1].value(forHTTPHeaderField: field))
        }
    }

    /// 인증 시간 밖·주말, 유예 시간이 지난 재시도가 같은 코드로 온다.
    @Test func outOfCertificationTimeMapsToDeadlinePassed() async throws {
        let repository = Self.makeRepository { _ in (403, Self.errorJSON("OUT_OF_CERTIFICATION_TIME")) }

        await #expect(throws: VerificationError.deadlinePassed) {
            try await repository.submit(Self.photo())
        }
    }

    @Test func vacationPeriodMapsToVacation() async throws {
        let repository = Self.makeRepository { _ in (403, Self.errorJSON("VACATION_PERIOD")) }

        await #expect(throws: VerificationError.vacation) {
            try await repository.submit(Self.photo())
        }
    }

    /// 다른 사진이 이미 접수됐다. 제출 시각은 에러 바디에서, 검수 상태는 오늘 인증 정보에서 가져온다.
    @Test func alreadySubmittedTodayCarriesSubmittedAtAndStatus() async throws {
        let log = RequestLog()
        let repository = Self.makeRepository { request in
            log.append(request)
            if request.url?.path() == Self.todayPath {
                return (200, Self.todayJSON(canSubmit: false, reason: "ALREADY_SUBMITTED", submitted: true, status: "MANUAL_REVIEW", submittedAt: "2026-09-29T07:41:05"))
            }
            return (409, Self.errorJSON("ALREADY_SUBMITTED_TODAY", submittedAt: "2026-09-29T07:41:05.123"))
        }

        await #expect(throws: VerificationError.alreadySubmitted(submittedAt: Self.kst(7, 41, 5), status: .manualReview)) {
            try await repository.submit(Self.photo())
        }
        #expect(log.requests(path: Self.todayPath).map(\.httpMethod) == ["GET"])
    }

    /// 오늘 인증 정보 조회가 실패해도 에러 바디의 제출 시각은 싣는다.
    @Test func alreadySubmittedTodayKeepsSubmittedAtWhenTodayFails() async throws {
        let repository = Self.makeRepository { request in
            if request.url?.path() == Self.todayPath { return (500, Data()) }
            return (409, Self.errorJSON("ALREADY_SUBMITTED_TODAY", submittedAt: "2026-09-29T07:41:05"))
        }

        await #expect(throws: VerificationError.alreadySubmitted(submittedAt: Self.kst(7, 41, 5), status: nil)) {
            try await repository.submit(Self.photo())
        }
    }

    /// 동시 제출 경합에서는 서버가 제출 시각 없이 보낸다. 오늘 인증 정보의 값을 쓴다.
    @Test func alreadySubmittedTodayWithoutBodyTimeUsesToday() async throws {
        let repository = Self.makeRepository { request in
            if request.url?.path() == Self.todayPath {
                return (200, Self.todayJSON(canSubmit: false, reason: "ALREADY_SUBMITTED", submitted: true, status: "PROCESSING", submittedAt: "2026-09-29T07:41:05"))
            }
            return (409, Self.errorJSON("ALREADY_SUBMITTED_TODAY"))
        }

        await #expect(throws: VerificationError.alreadySubmitted(submittedAt: Self.kst(7, 41, 5), status: .processing)) {
            try await repository.submit(Self.photo())
        }
    }

    @Test(arguments: [(400, "INVALID_IMAGE"), (403, "NOT_ASSIGNED_AREA"), (404, "NO_ASSIGNMENT")])
    func otherServerErrorsPassThrough(statusCode: Int, code: String) async throws {
        let repository = Self.makeRepository { _ in (statusCode, Self.errorJSON(code)) }

        await #expect(throws: APIError.server(statusCode: statusCode, code: code)) {
            try await repository.submit(Self.photo())
        }
    }
}
