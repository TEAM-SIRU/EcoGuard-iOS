import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct MyPageRepositoryImplTests {
    private enum Path {
        static let activity = "/api/v1/service-times/me"
        static let assignment = "/api/v1/assignments/me"
        static let application = "/api/v1/applications/me"
    }

    private static let activityJSON = """
    {"totalMinutes":300,"year":2026,"month":10,"monthlyMinutes":70,
     "summary":{"completedDays":7,"requiredDays":22,"approvedCount":7,"rejectedCount":1,"notSubmittedCount":0},"records":[]}
    """

    private func makeRepository(log: RequestLog = RequestLog(), responses: [String: (Int, String)]) -> MyPageRepositoryImpl {
        // 2026-10-01 00:30 KST(UTC로는 9월 30일). 이번 달은 학교 시간대로 정한다.
        MyPageRepositoryImpl(apiClient: PathStub.makeClient(log: log, responses: responses), now: { PathStub.date(2026, 10, 1, 0, 30) })
    }

    @Test func guardianSummaryCombinesActivityAssignmentAndApplication() async throws {
        let log = RequestLog()
        let repository = makeRepository(log: log, responses: [
            Path.activity: (200, Self.activityJSON),
            Path.assignment: (200, #"{"areaId":3,"areaName":"본관 계단 A","description":null,"cleanTime":null,"mapCoordinates":{"x":0,"y":0},"members":[]}"#),
            Path.application: (200, #"{"status":"APPROVED","order":2,"waitingForAssignment":false}"#)
        ])

        let summary = try await repository.fetchMyPage()

        let activity = try #require(log.requests(path: Path.activity).first)
        #expect(activity.httpMethod == "GET")
        #expect(activity.url?.query() == "year=2026&month=10")
        #expect(summary == MyPageSummary(
            profile: UserProfile(name: nil, grade: nil, classNumber: nil, isGuardian: true),
            monthlyApprovedCount: 7,
            monthlyActivityMinutes: 70,
            cleaningAreaName: "본관 계단 A",
            hasApplied: true
        ))
    }

    @Test func notAppliedStudentHasNoAreaOrRole() async throws {
        let repository = makeRepository(responses: [
            Path.activity: (200, Self.activityJSON),
            Path.assignment: (404, PathStub.error("NO_ASSIGNMENT")),
            Path.application: (404, PathStub.error("NO_APPLICATION"))
        ])

        let summary = try await repository.fetchMyPage()

        #expect(summary.profile.isGuardian == false)
        #expect(summary.cleaningAreaName == nil)
        #expect(summary.hasApplied == false)
    }

    /// 신청했지만 아직 선발 전이면 환경지킴이가 아니다.
    @Test func pendingApplicationIsNotGuardian() async throws {
        let repository = makeRepository(responses: [
            Path.activity: (200, Self.activityJSON),
            Path.assignment: (404, PathStub.error("NO_ASSIGNMENT")),
            Path.application: (200, #"{"status":"PENDING","order":2,"waitingForAssignment":false}"#)
        ])

        let summary = try await repository.fetchMyPage()

        #expect(summary.profile.isGuardian == false)
        #expect(summary.hasApplied)
    }

    @Test func activityFailureFailsMyPage() async {
        let repository = makeRepository(responses: [
            Path.activity: (403, PathStub.error("FORBIDDEN")),
            Path.assignment: (404, PathStub.error("NO_ASSIGNMENT")),
            Path.application: (404, PathStub.error("NO_APPLICATION"))
        ])

        await #expect(throws: APIError.server(statusCode: 403, code: "FORBIDDEN")) {
            try await repository.fetchMyPage()
        }
    }
}

/// 실제 저장소들이 로그인 저장소와 같은 `AuthSession`을 쓴다(토큰 재발급이 하나로 묶인다).
@MainActor
struct DIContainerAPIClientTests {
    @Test func apiClientIsSharedWithAuthRepository() throws {
        let suiteName = "DIContainerAPIClientTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        func container(apiBaseURL: URL?) -> DIContainer {
            DIContainer(
                authRepository: DIContainer.makeAuthRepository(apiBaseURL: apiBaseURL, tokenStore: InMemoryTokenStore(), defaults: defaults),
                homeRepository: MockHomeRepository(delay: .zero),
                recruitmentRepository: MockRecruitmentRepository(delay: .zero),
                webAdminURL: nil
            )
        }

        let live = container(apiBaseURL: PathStub.baseURL)
        let auth = try #require(live.authRepository as? AuthRepositoryImpl)
        let apiClient = try #require(live.apiClient)
        #expect(apiClient.authSession === auth.apiClient.authSession)
        #expect(container(apiBaseURL: nil).apiClient == nil)
    }
}
