import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct VerificationResultRepositoryImplTests {
    private nonisolated static let reviewPath = "/api/v1/verifications/7/review"
    private nonisolated static let mePath = "/api/v1/verifications/me"

    private static func makeRepository(handler: @escaping StubURLProtocol.Handler) -> VerificationResultRepositoryImpl {
        let httpClient = HTTPClient(
            baseURL: URL(string: "https://api.example.com")!,
            session: StubURLProtocol.makeSession(handler: handler)
        )
        let store = InMemoryTokenStore(AuthTokens(accessToken: "access", refreshToken: "refresh"))
        return VerificationResultRepositoryImpl(
            apiClient: APIClient(httpClient: httpClient, authSession: AuthSession(tokenStore: store, httpClient: httpClient))
        )
    }

    /// 목록 응답의 상태는 일부러 오래된 값(PROCESSING)으로 둔다. 결과 상태는 한 건 조회 값을 써야 한다.
    private nonisolated static let meJSON = Data(#"""
    [
      {"verificationId":8,"photoUrl":"/files/verifications/b.jpg","date":"2026-09-30","areaName":"별관","reviewStatus":"APPROVED","failReasons":null},
      {"verificationId":7,"photoUrl":"/files/verifications/a.jpg","date":"2026-09-29","areaName":"본관 2층 복도 A","reviewStatus":"PROCESSING","failReasons":null}
    ]
    """#.utf8)

    private static func response(review: Data, me: Data = meJSON, log: RequestLog? = nil) -> StubURLProtocol.Handler {
        { request in
            log?.append(request)
            switch request.url?.path() {
            case reviewPath: return (200, review)
            case mePath: return (200, me)
            default: return (404, Data())
            }
        }
    }

    private static func kst(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func rejectedResultCombinesReviewAndList() async throws {
        let log = RequestLog()
        let review = Data(#"{"status":"REJECTED","failReasons":["구역이 보이지 않아요","쓰레기가 남아 있어요"]}"#.utf8)
        let repository = Self.makeRepository(handler: Self.response(review: review, log: log))

        let result = try await repository.fetchResult(id: "7")

        #expect(result == VerificationResult(
            id: "7",
            submittedAt: Self.kst(2026, 9, 29),
            area: "본관 2층 복도 A",
            status: .rejected,
            rejectionReason: .init(title: "구역이 보이지 않아요", guide: "쓰레기가 남아 있어요"),
            earnedMinutes: 0,
            photoURL: URL(string: "https://api.example.com/files/verifications/a.jpg")
        ))
        #expect(log.requests(path: Self.reviewPath).map(\.httpMethod) == ["GET"])
        #expect(log.requests(path: Self.mePath).map(\.httpMethod) == ["GET"])
    }

    @Test(arguments: [
        ("PROCESSING", VerificationResult.Status.processing, 0),
        ("APPROVED", .approved, 10),
        ("MANUAL_REVIEW", .manualReview, 0)
    ])
    func statusMapping(raw: String, status: VerificationResult.Status, minutes: Int) async throws {
        let review = Data(#"{"status":"\#(raw)","failReasons":null}"#.utf8)
        let repository = Self.makeRepository(handler: Self.response(review: review))

        let result = try await repository.fetchResult(id: "7")

        #expect(result.status == status)
        #expect(result.earnedMinutes == minutes)
        #expect(result.rejectionReason == nil)
    }

    /// 사유 없이 반려(선생님 수동 반려 등)되면 사유를 비운다.
    @Test func rejectedWithoutReasons() async throws {
        let review = Data(#"{"status":"REJECTED","failReasons":[]}"#.utf8)
        let repository = Self.makeRepository(handler: Self.response(review: review))

        #expect(try await repository.fetchResult(id: "7").rejectionReason == nil)
    }

    @Test func reviewNotFoundPassesThrough() async throws {
        let repository = Self.makeRepository { request in
            request.url?.path() == Self.reviewPath
                ? (404, Data(#"{"code":"REVIEW_NOT_FOUND","message":"m"}"#.utf8))
                : (200, Self.meJSON)
        }

        await #expect(throws: APIError.server(statusCode: 404, code: "REVIEW_NOT_FOUND")) {
            try await repository.fetchResult(id: "7")
        }
    }

    @Test func missingFromListIsInvalidResponse() async throws {
        let review = Data(#"{"status":"APPROVED","failReasons":null}"#.utf8)
        let repository = Self.makeRepository(handler: Self.response(review: review, me: Data("[]".utf8)))

        await #expect(throws: APIError.invalidResponse) {
            try await repository.fetchResult(id: "7")
        }
    }

    @Test func malformedDateIsDecodingError() async throws {
        let review = Data(#"{"status":"APPROVED","failReasons":null}"#.utf8)
        let me = Data(#"[{"verificationId":7,"photoUrl":"/a.jpg","date":"2026/09/29","areaName":"A","reviewStatus":"APPROVED"}]"#.utf8)
        let repository = Self.makeRepository(handler: Self.response(review: review, me: me))

        await #expect(throws: APIError.decoding) {
            try await repository.fetchResult(id: "7")
        }
    }
}
