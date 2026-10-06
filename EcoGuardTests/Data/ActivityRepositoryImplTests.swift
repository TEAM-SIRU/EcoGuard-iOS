import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct ActivityRepositoryImplTests {
    private static let path = "/api/v1/service-times/me"

    private static let monthJSON = """
    {"totalMinutes":120,"year":2026,"month":9,"monthlyMinutes":20,
     "summary":{"completedDays":2,"requiredDays":21,"approvedCount":2,"rejectedCount":1,"notSubmittedCount":1},
     "records":[
      {"date":"2026-09-29","area":"본관 계단 A","result":"MANUAL_REVIEW","verificationId":15,"photoUrl":"/files/15.jpg","minutes":0},
      {"date":"2026-09-28","area":"본관 계단 A","result":"APPROVED","verificationId":14,"photoUrl":"/files/14.jpg","minutes":10},
      {"date":"2026-09-25","area":null,"result":"NOT_SUBMITTED","verificationId":null,"photoUrl":null,"minutes":0},
      {"date":"2026-09-24","area":"본관 계단 A","result":"REJECTED","verificationId":12,"photoUrl":"/files/12.jpg","minutes":0},
      {"date":"2026-09-23","area":"본관 계단 A","result":"PROCESSING","verificationId":11,"photoUrl":"/files/11.jpg","minutes":0},
      {"date":"2026-09-30","area":"본관 계단 A","result":"UPCOMING","verificationId":null,"photoUrl":null,"minutes":0}
     ]}
    """

    @Test func fetchMonthSendsYearMonthQueryAndMapsRecords() async throws {
        let log = RequestLog()
        let repository = ActivityRepositoryImpl(apiClient: PathStub.makeClient(log: log, responses: [Self.path: (200, Self.monthJSON)]))

        let month = try await repository.fetchMonth(year: 2026, month: 9)

        let request = try #require(log.requests(path: Self.path).first)
        #expect(request.httpMethod == "GET")
        #expect(request.bearerToken == PathStub.tokens.accessToken)
        let query = URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.queryItems
        #expect(query == [URLQueryItem(name: "year", value: "2026"), URLQueryItem(name: "month", value: "9")])

        #expect(month.month == YearMonth(year: 2026, month: 9))
        #expect(month.holidays.isEmpty)
        // UPCOMING은 기록이 아니다.
        #expect(month.records.map(\.result) == [.reviewing, .approved, .notSubmitted, .rejected, .reviewing])
        #expect(month.totalMinutes == 10)
        let approved = month.records[1]
        #expect(approved == ActivityRecord(
            id: "2026-09-28",
            date: PathStub.date(2026, 9, 28),
            area: "본관 계단 A",
            result: .approved,
            submittedAt: nil,
            verificationID: "14",
            earnedMinutes: 10,
            isAppealApproved: false
        ))
        let notSubmitted = month.records[2]
        #expect(notSubmitted.area == nil)
        #expect(notSubmitted.verificationID == nil)
    }

    @Test(arguments: [(400, "VALIDATION_ERROR"), (403, "FORBIDDEN"), (500, "INTERNAL_SERVER_ERROR")])
    func serverErrorsKeepStatusAndCode(statusCode: Int, code: String) async {
        let repository = ActivityRepositoryImpl(apiClient: PathStub.makeClient(
            log: RequestLog(),
            responses: [Self.path: (statusCode, PathStub.error(code))]
        ))

        await #expect(throws: APIError.server(statusCode: statusCode, code: code)) {
            try await repository.fetchMonth(year: 2026, month: 13)
        }
    }

    @Test func malformedDateIsDecodingError() async {
        let json = Self.monthJSON.replacingOccurrences(of: "2026-09-28", with: "9월 28일")
        let repository = ActivityRepositoryImpl(apiClient: PathStub.makeClient(log: RequestLog(), responses: [Self.path: (200, json)]))

        await #expect(throws: APIError.decoding) {
            try await repository.fetchMonth(year: 2026, month: 9)
        }
    }
}
