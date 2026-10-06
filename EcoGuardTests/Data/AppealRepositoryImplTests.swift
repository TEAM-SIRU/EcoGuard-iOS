import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct AppealRepositoryImplTests {
    private nonisolated static let mePath = "/api/v1/appeals/me"
    private nonisolated static let createPath = "/api/v1/verifications/7/appeals"

    private static func makeRepository(handler: @escaping StubURLProtocol.Handler) -> AppealRepositoryImpl {
        let httpClient = HTTPClient(
            baseURL: URL(string: "https://api.example.com")!,
            session: StubURLProtocol.makeSession(handler: handler)
        )
        let store = InMemoryTokenStore(AuthTokens(accessToken: "access", refreshToken: "refresh"))
        return AppealRepositoryImpl(
            apiClient: APIClient(httpClient: httpClient, authSession: AuthSession(tokenStore: store, httpClient: httpClient))
        )
    }

    private nonisolated static func appealJSON(
        id: Int,
        verificationID: Int = 7,
        round: Int = 1,
        status: String,
        awardedMinutes: Int? = nil,
        replyTitle: String? = nil,
        reply: String? = nil,
        photoURLs: [String] = [],
        createdAt: String = "2026-09-29T12:20:05.123456"
    ) -> String {
        func json(_ value: String?) -> String { value.map { "\"\($0)\"" } ?? "null" }
        let photos = photoURLs.map { "\"\($0)\"" }.joined(separator: ",")
        return #"{"appealId":\#(id),"verificationId":\#(verificationID),"round":\#(round),"areaName":"본관","verificationDate":"2026-09-22","content":"c","photoUrls":[\#(photos)],"status":"\#(status)","awardedMinutes":\#(awardedMinutes.map(String.init) ?? "null"),"replyTitle":\#(json(replyTitle)),"reply":\#(json(reply)),"createdAt":"\#(createdAt)"}"#
    }

    private nonisolated static func list(_ items: String...) -> Data {
        Data("[\(items.joined(separator: ","))]".utf8)
    }

    private static func kst(_ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    private static let draft = AppealDraft(requestID: "req-1", verificationID: "7", message: "다시 봐 주세요", photos: [])

    @Test func fetchAppealsMapsStatusesAndDates() async throws {
        let log = RequestLog()
        let repository = Self.makeRepository { request in
            log.append(request)
            return (200, Self.list(
                Self.appealJSON(id: 3, round: 2, status: "PENDING"),
                Self.appealJSON(id: 2, status: "REJECTED", reply: "표지판이 보이지 않아요", createdAt: "2026-09-22T13:02:00"),
                Self.appealJSON(id: 1, verificationID: 6, status: "APPROVED", awardedMinutes: 10, reply: "확인했어요")
            ))
        }

        let appeals = try await repository.fetchAppeals()

        #expect(log.requests(path: Self.mePath).map(\.httpMethod) == ["GET"])
        #expect(appeals.map(\.id) == ["3", "2", "1"])
        #expect(appeals.map(\.status) == [.reviewing, .rejected, .approved])
        #expect(appeals.map(\.earnedMinutes) == [0, 0, 10])
        #expect(appeals[0] == Appeal(
            id: "3",
            verificationID: "7",
            verifiedAt: Self.kst(9, 22),
            round: 2,
            submittedAt: Self.kst(9, 29, 12, 20, 5),
            status: .reviewing,
            earnedMinutes: 0,
            teacherReply: nil,
            photoURLs: [],
            isVerifiedTimeKnown: false
        ))
        #expect(appeals[1].submittedAt == Self.kst(9, 22, 13, 2))
        #expect(appeals[1].teacherReply == .init(title: "표지판이 보이지 않아요", message: nil))
        // 승인 답변은 반려 사유가 아니라 쓰지 않는다.
        #expect(appeals[2].teacherReply == nil)
    }

    @Test func submitPostsContentThenReturnsAppealFromHistory() async throws {
        let log = RequestLog()
        let repository = Self.makeRepository { request in
            log.append(request)
            if request.url?.path() == Self.createPath {
                return (201, Data(#"{"appealId":9,"status":"PENDING","round":2}"#.utf8))
            }
            return (200, Self.list(Self.appealJSON(id: 9, round: 2, status: "PENDING"), Self.appealJSON(id: 2, status: "REJECTED")))
        }

        let appeal = try await repository.submitAppeal(Self.draft)

        #expect(appeal.id == "9")
        #expect(appeal.round == 2)
        #expect(appeal.status == .reviewing)
        let create = try #require(log.requests(path: Self.createPath).first)
        #expect(create.httpMethod == "POST")
        #expect(create.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try JSONDecoder().decode([String: String].self, from: try #require(create.bodyData))
        #expect(body == ["content": "다시 봐 주세요"])
    }

    /// 같은 인증에 검토 중인 이의신청이 이미 있으면 그 이의신청을 들고 `alreadyPending`, 제출 흐름은 `alreadyReceived`.
    @Test func alreadyPendingMapsToAlreadyReceived() async throws {
        let log = RequestLog()
        let repository = Self.makeRepository { request in
            log.append(request)
            if request.url?.path() == Self.createPath {
                return (409, Data(#"{"code":"APPEAL_ALREADY_PENDING","message":"m"}"#.utf8))
            }
            return (200, Self.list(
                Self.appealJSON(id: 5, verificationID: 6, status: "PENDING"),
                Self.appealJSON(id: 4, round: 2, status: "PENDING"),
                Self.appealJSON(id: 2, status: "REJECTED")
            ))
        }

        await #expect(throws: AppealError.self) {
            try await repository.submitAppeal(Self.draft)
        }
        let result = try await SubmitAppealUseCase(appealRepository: repository).execute(Self.draft, unconfirmedAttempts: [])

        guard case .alreadyReceived(let appeal) = result else {
            Issue.record("\(result)")
            return
        }
        #expect(appeal.id == "4")
        #expect(appeal.round == 2)
        #expect(log.requests(path: Self.createPath).count == 2)
    }

    /// 검토 중인 이의신청을 찾지 못하면(그새 처리됨) 서버 오류 그대로.
    @Test func alreadyPendingWithoutPendingAppealPassesThrough() async throws {
        let repository = Self.makeRepository { request in
            if request.url?.path() == Self.createPath {
                return (409, Data(#"{"code":"APPEAL_ALREADY_PENDING","message":"m"}"#.utf8))
            }
            return (200, Self.list(Self.appealJSON(id: 2, status: "REJECTED")))
        }

        await #expect(throws: APIError.server(statusCode: 409, code: "APPEAL_ALREADY_PENDING")) {
            try await repository.submitAppeal(Self.draft)
        }
    }

    @Test(arguments: [("APPEAL_NOT_ALLOWED", 409), ("VERIFICATION_NOT_FOUND", 404)])
    func submitServerErrorsPassThrough(code: String, statusCode: Int) async throws {
        let repository = Self.makeRepository { _ in
            (statusCode, Data(#"{"code":"\#(code)","message":"m"}"#.utf8))
        }

        await #expect(throws: APIError.server(statusCode: statusCode, code: code)) {
            try await repository.submitAppeal(Self.draft)
        }
    }

    /// 접수됐지만 응답을 받지 못한 제출 → 같은 `requestID` 조회가 그 인증의 검토 중 이의신청을 찾는다.
    @Test func fetchByRequestIDFindsPendingAppealAfterLostResponse() async throws {
        let log = RequestLog()
        let repository = Self.makeRepository { request in
            log.append(request)
            if request.url?.path() == Self.createPath { throw URLError(.networkConnectionLost) }
            return (200, Self.list(
                Self.appealJSON(id: 5, verificationID: 6, status: "PENDING"),
                Self.appealJSON(id: 4, status: "PENDING"),
                Self.appealJSON(id: 2, status: "REJECTED")
            ))
        }

        await #expect(throws: URLError.self) {
            try await repository.submitAppeal(Self.draft)
        }
        let found = try await repository.fetchAppeal(requestID: Self.draft.requestID)

        #expect(found?.id == "4")
    }

    @Test func fetchByRequestIDIsNilWhenNotReceived() async throws {
        let repository = Self.makeRepository { request in
            if request.url?.path() == Self.createPath { throw URLError(.networkConnectionLost) }
            return (200, Self.list(Self.appealJSON(id: 2, status: "REJECTED")))
        }

        await #expect(throws: URLError.self) {
            try await repository.submitAppeal(Self.draft)
        }

        #expect(try await repository.fetchAppeal(requestID: Self.draft.requestID) == nil)
    }

    /// 이 저장소로 보낸 적 없는 `requestID`는 서버에 묻지 않는다.
    @Test func fetchByUnknownRequestIDSkipsServer() async throws {
        let log = RequestLog()
        let repository = Self.makeRepository { request in
            log.append(request)
            return (200, Self.list())
        }

        #expect(try await repository.fetchAppeal(requestID: "unknown") == nil)
        #expect(log.requests.isEmpty)
    }

    // MARK: - 사진 첨부

    private static func draft(photoCount: Int) -> AppealDraft {
        AppealDraft(
            requestID: "req-1",
            verificationID: "7",
            message: "다시 봐 주세요",
            photos: (0..<photoCount).map { AppealPhoto(id: UUID(), jpegData: Data([0xFF, 0xD8, UInt8($0), 0xFF, 0xD9])) }
        )
    }

    private nonisolated static func created(_ request: URLRequest) -> (Int, Data) {
        if request.url?.path() == createPath {
            return (201, Data(#"{"appealId":9,"status":"PENDING","round":1}"#.utf8))
        }
        return (200, list(appealJSON(id: 9, status: "PENDING")))
    }

    /// 사진이 있으면 서버 `createWithPhotos`: `content`(@RequestParam) 글자 파트 뒤에 `photos`(@RequestPart) 파일 파트를 장수만큼.
    @Test(arguments: [1, 2, 3])
    func submitWithPhotosSendsContentAndPhotoParts(photoCount: Int) async throws {
        let log = RequestLog()
        let repository = Self.makeRepository { request in
            log.append(request)
            return Self.created(request)
        }
        let draft = Self.draft(photoCount: photoCount)

        _ = try await repository.submitAppeal(draft)

        let create = try #require(log.requests(path: Self.createPath).first)
        #expect(create.httpMethod == "POST")
        let contentType = try #require(create.value(forHTTPHeaderField: "Content-Type"))
        #expect(contentType.hasPrefix("multipart/form-data; boundary="))
        let boundary = String(contentType.dropFirst("multipart/form-data; boundary=".count))
        var expected = Data((
            "--\(boundary)\r\n"
            + "Content-Disposition: form-data; name=\"content\"\r\n"
            + "Content-Type: text/plain; charset=utf-8\r\n\r\n"
            + "다시 봐 주세요\r\n"
        ).utf8)
        for (index, photo) in draft.photos.enumerated() {
            expected.append(Data((
                "--\(boundary)\r\n"
                + "Content-Disposition: form-data; name=\"photos\"; filename=\"photo-\(index + 1).jpg\"\r\n"
                + "Content-Type: image/jpeg\r\n\r\n"
            ).utf8))
            expected.append(photo.jpegData)
            expected.append(Data("\r\n".utf8))
        }
        expected.append(Data("--\(boundary)--\r\n".utf8))
        #expect(create.bodyData == expected)
    }

    /// 사진이 없으면 서버 JSON 엔드포인트로 보낸다(파일 파트 없음).
    @Test func submitWithoutPhotosSendsJSON() async throws {
        let log = RequestLog()
        let repository = Self.makeRepository { request in
            log.append(request)
            return Self.created(request)
        }

        _ = try await repository.submitAppeal(Self.draft(photoCount: 0))

        let create = try #require(log.requests(path: Self.createPath).first)
        #expect(create.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try JSONDecoder().decode([String: String].self, from: try #require(create.bodyData))
        #expect(body == ["content": "다시 봐 주세요"])
    }

    /// 토큰 재발급 뒤 다시 보낼 때도 같은 사진 바디·경계를 그대로 보낸다.
    @Test func retryAfterRefreshResendsSameMultipartBody() async throws {
        let log = RequestLog()
        let repository = Self.makeRepository { request in
            log.append(request)
            if request.url?.path() == "/api/v1/auth/refresh" {
                return (200, Data(#"{"accessToken":"access-new","refreshToken":"refresh-new"}"#.utf8))
            }
            guard request.bearerToken == "access-new" else { return (401, Data()) }
            return Self.created(request)
        }

        let appeal = try await repository.submitAppeal(Self.draft(photoCount: 3))

        #expect(appeal.id == "9")
        let uploads = log.requests(path: Self.createPath)
        #expect(uploads.map(\.bearerToken) == ["access", "access-new"])
        #expect(uploads[0].bodyData != nil && uploads[0].bodyData == uploads[1].bodyData)
        #expect(uploads[0].value(forHTTPHeaderField: "Content-Type") == uploads[1].value(forHTTPHeaderField: "Content-Type"))
    }

    /// 사진을 붙여도 검토 중인 이의신청이 있으면 `alreadyReceived`이고, 사진 제출은 한 번뿐이다.
    @Test func alreadyPendingWithPhotosMapsToAlreadyReceived() async throws {
        let log = RequestLog()
        let repository = Self.makeRepository { request in
            log.append(request)
            if request.url?.path() == Self.createPath {
                return (409, Data(#"{"code":"APPEAL_ALREADY_PENDING","message":"m"}"#.utf8))
            }
            return (200, Self.list(Self.appealJSON(id: 4, round: 2, status: "PENDING", photoURLs: ["/files/appeals/a.jpg"])))
        }

        let result = try await SubmitAppealUseCase(appealRepository: repository)
            .execute(Self.draft(photoCount: 2), unconfirmedAttempts: [])

        #expect(result == .alreadyReceived(try #require(try await repository.fetchAppeals().first)))
        #expect(log.requests(path: Self.createPath).count == 1)
    }

    @Test(arguments: [("TOO_MANY_APPEAL_PHOTOS", 400), ("INVALID_IMAGE", 400), ("VALIDATION_ERROR", 400)])
    func submitWithPhotosServerErrorsPassThrough(code: String, statusCode: Int) async throws {
        let repository = Self.makeRepository { _ in
            (statusCode, Data(#"{"code":"\#(code)","message":"m"}"#.utf8))
        }

        await #expect(throws: APIError.server(statusCode: statusCode, code: code)) {
            try await repository.submitAppeal(Self.draft(photoCount: 1))
        }
    }

    // MARK: - 새 필드 매핑

    /// 적립 분은 서버 `awardedMinutes`를 쓰고, 승인인데 값이 없으면 0이다.
    @Test(arguments: [(Optional(10), 10), (Optional(15), 15), (nil, 0)])
    func approvedUsesAwardedMinutes(awarded: Int?, expected: Int) async throws {
        let repository = Self.makeRepository { _ in
            (200, Self.list(Self.appealJSON(id: 1, status: "APPROVED", awardedMinutes: awarded)))
        }

        #expect(try await repository.fetchAppeals().first?.earnedMinutes == expected)
    }

    /// 반려 답변: 제목이 있으면 제목·본문으로 나누고, 제목이 없으면 본문을 제목으로 쓴다. 공백뿐인 값은 없는 것으로 본다.
    @Test func rejectedReplySplitsTitleAndBody() async throws {
        let repository = Self.makeRepository { _ in
            (200, Self.list(
                Self.appealJSON(id: 4, status: "REJECTED", replyTitle: "표지판이 안 보여요", reply: "다시 찍어 주세요"),
                Self.appealJSON(id: 3, status: "REJECTED", replyTitle: "표지판이 안 보여요"),
                Self.appealJSON(id: 2, status: "REJECTED", replyTitle: " ", reply: "다시 찍어 주세요"),
                Self.appealJSON(id: 1, status: "REJECTED")
            ))
        }

        let replies = try await repository.fetchAppeals().map(\.teacherReply)

        #expect(replies == [
            .init(title: "표지판이 안 보여요", message: "다시 찍어 주세요"),
            .init(title: "표지판이 안 보여요", message: nil),
            .init(title: "다시 찍어 주세요", message: nil),
            nil
        ])
    }

    /// 사진 주소는 상대 경로면 API 주소 기준으로 바꾸고, 읽지 못한 주소는 뺀다.
    @Test func photoURLsResolveAgainstBaseURL() async throws {
        let repository = Self.makeRepository { _ in
            (200, Self.list(Self.appealJSON(
                id: 1,
                status: "PENDING",
                photoURLs: ["/files/appeals/a.jpg", "https://cdn.example.com/b.png", ""]
            )))
        }

        let appeal = try #require(try await repository.fetchAppeals().first)

        #expect(appeal.photoURLs == [
            URL(string: "https://api.example.com/files/appeals/a.jpg")!,
            URL(string: "https://cdn.example.com/b.png")!
        ])
    }

    @Test func malformedCreatedAtIsDecodingError() async throws {
        let repository = Self.makeRepository { _ in
            (200, Self.list(Self.appealJSON(id: 1, status: "PENDING", createdAt: "2026-09-29 12:20")))
        }

        await #expect(throws: APIError.decoding) {
            try await repository.fetchAppeals()
        }
    }
}
