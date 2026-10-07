import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct MyPageRepositoryImplTests {
    private enum Path {
        static let activity = "/api/v1/service-times/me"
        static let assignment = "/api/v1/assignments/me"
        static let application = "/api/v1/applications/me"
        static let recruitment = "/api/v1/recruitments/current"
    }

    private static let activityJSON = """
    {"totalMinutes":300,"year":2026,"month":10,"monthlyMinutes":70,
     "summary":{"completedDays":7,"requiredDays":22,"approvedCount":7,"rejectedCount":1,"notSubmittedCount":0},"records":[]}
    """

    private func makeRepository(
        log: RequestLog = RequestLog(),
        user: CurrentUser? = CurrentUser(id: "1", name: "김학생", studentNumber: "2310", grade: 2, classNumber: 3),
        responses: [String: (Int, String)]
    ) -> MyPageRepositoryImpl {
        // 2026-10-01 00:30 KST(UTC로는 9월 30일). 이번 달은 학교 시간대로 정한다.
        MyPageRepositoryImpl(
            // 공고를 주지 않은 테스트는 공고 없음(현재 공고에 신청하지 않음)으로 둔다.
            apiClient: PathStub.makeClient(
                log: log,
                responses: responses.merging([Path.recruitment: (404, PathStub.error("NO_ACTIVE_RECRUITMENT"))]) { given, _ in given }
            ),
            currentUserRepository: MockCurrentUserRepository(user: user),
            now: { PathStub.date(2026, 10, 1, 0, 30) }
        )
    }

    @Test func guardianSummaryCombinesActivityAssignmentAndApplication() async throws {
        let log = RequestLog()
        let repository = makeRepository(log: log, responses: [
            Path.activity: (200, Self.activityJSON),
            Path.assignment: (200, #"{"areaId":3,"areaName":"본관 계단 A","description":null,"cleanTime":null,"members":[],"zoneCode":"main_stair_a"}"#),
            Path.recruitment: (200, HomeRepositoryImplTests.recruitmentJSON(status: "CLOSED", alreadyApplied: true)),
            Path.application: (200, #"{"recruitmentId":1,"status":"APPROVED","order":2,"appliedAt":"2026-09-01T08:00:00","waitingForAssignment":false}"#)
        ])

        let summary = try await repository.fetchMyPage()

        let activity = try #require(log.requests(path: Path.activity).first)
        #expect(activity.httpMethod == "GET")
        #expect(activity.url?.query() == "year=2026&month=10")
        #expect(summary == MyPageSummary(
            profile: UserProfile(name: "김학생", grade: 2, classNumber: 3, isGuardian: true),
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

    /// 현재 공고에 신청했으면 신청은 바로 승인된다(서버 #16). 이전 데이터의 `PENDING`도 받아들여진 신청이고, 미선발(`REJECTED`)만 환경지킴이가 아니다.
    @Test(arguments: [("APPROVED", true), ("PENDING", true), ("REJECTED", false)])
    func applicationStatusDecidesGuardian(status: String, isGuardian: Bool) async throws {
        let repository = makeRepository(responses: [
            Path.activity: (200, Self.activityJSON),
            Path.assignment: (404, PathStub.error("NO_ASSIGNMENT")),
            Path.recruitment: (200, HomeRepositoryImplTests.recruitmentJSON(status: "OPEN", alreadyApplied: true)),
            Path.application: (200, #"{"recruitmentId":1,"status":"\#(status)","order":2,"appliedAt":"2026-09-01T08:00:00","waitingForAssignment":false}"#)
        ])

        let summary = try await repository.fetchMyPage()

        #expect(summary.profile.isGuardian == isGuardian)
        #expect(summary.hasApplied)
    }

    /// 현재 공고에 신청했어도 가장 최근 신청이 다른 공고의 것이면 그 결과로 환경지킴이를 정하지 않는다.
    @Test func otherRecruitmentApplicationIsNotGuardian() async throws {
        let repository = makeRepository(responses: [
            Path.activity: (200, Self.activityJSON),
            Path.assignment: (404, PathStub.error("NO_ASSIGNMENT")),
            Path.recruitment: (200, HomeRepositoryImplTests.recruitmentJSON(status: "OPEN", alreadyApplied: true)),
            Path.application: (200, #"{"recruitmentId":99,"status":"APPROVED","order":2,"appliedAt":"2026-03-02T08:00:00","waitingForAssignment":false}"#)
        ])

        let summary = try await repository.fetchMyPage()

        #expect(summary.profile.isGuardian == false)
        #expect(summary.hasApplied)
    }

    /// `applications/me`는 지난 모집의 신청일 수 있어, 현재 공고에 신청하지 않았거나 공고가 없으면 보지 않는다.
    @Test(arguments: [
        (200, HomeRepositoryImplTests.recruitmentJSON(status: "OPEN", alreadyApplied: false)),
        (404, PathStub.error("NO_ACTIVE_RECRUITMENT"))
    ])
    func pastApplicationIsNotGuardian(statusCode: Int, recruitmentJSON: String) async throws {
        let log = RequestLog()
        let repository = makeRepository(log: log, responses: [
            Path.activity: (200, Self.activityJSON),
            Path.assignment: (404, PathStub.error("NO_ASSIGNMENT")),
            Path.recruitment: (statusCode, recruitmentJSON),
            Path.application: (200, #"{"recruitmentId":1,"status":"PENDING","order":2,"appliedAt":"2026-03-02T08:00:00","waitingForAssignment":false}"#)
        ])

        let summary = try await repository.fetchMyPage()

        #expect(summary.profile.isGuardian == false)
        #expect(summary.hasApplied == false)
        #expect(log.requests(path: Path.application).isEmpty)
    }

    /// 내 정보를 받지 못하고 저장한 값도 없으면 이름·학반을 비우고 나머지는 보여 준다.
    @Test func missingUserLeavesNameEmpty() async throws {
        let repository = makeRepository(user: nil, responses: [
            Path.activity: (200, Self.activityJSON),
            Path.assignment: (404, PathStub.error("NO_ASSIGNMENT")),
            Path.application: (404, PathStub.error("NO_APPLICATION"))
        ])

        let summary = try await repository.fetchMyPage()

        #expect(summary.profile == UserProfile(name: "", grade: nil, classNumber: nil, isGuardian: false))
        #expect(summary.monthlyActivityMinutes == 70)
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
