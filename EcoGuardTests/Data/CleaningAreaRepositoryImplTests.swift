import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct CleaningAreaRepositoryImplTests {
    private static let path = "/api/v1/assignments/me"

    private func makeRepository(
        log: RequestLog = RequestLog(),
        currentUser: CurrentUser? = CurrentUser(id: "2", name: "이도윤", studentNumber: nil, grade: 2, classNumber: 3),
        statusCode: Int,
        json: String
    ) -> CleaningAreaRepositoryImpl {
        let data = Data(json.utf8)
        let httpClient = HTTPClient(
            baseURL: URL(string: "https://api.example.com")!,
            session: StubURLProtocol.makeSession { request in
                log.append(request)
                return (statusCode, data)
            }
        )
        let authSession = AuthSession(
            tokenStore: InMemoryTokenStore(AuthTokens(accessToken: "access", refreshToken: "refresh")),
            httpClient: httpClient
        )
        return CleaningAreaRepositoryImpl(
            apiClient: APIClient(httpClient: httpClient, authSession: authSession),
            currentUserRepository: MockCurrentUserRepository(user: currentUser)
        )
    }

    private static func assignmentJSON(cleanTime: String = #""07:20~08:10""#) -> String {
        """
        {"areaId":3,"areaName":"본관 계단 A","description":"1층→4층","cleanTime":\(cleanTime),
         "mapCoordinates":{"x":0.0,"y":0.0},
         "members":[{"studentId":1,"studentNumber":"2301","name":"김서연"},{"studentId":2,"studentNumber":null,"name":"이도윤"}]}
        """
    }

    @Test func assignedAreaMapsResponse() async throws {
        let log = RequestLog()
        let repository = makeRepository(log: log, statusCode: 200, json: Self.assignmentJSON())

        let summary = try await repository.fetchCleaningArea()

        let request = try #require(log.requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.path() == Self.path)
        #expect(request.bearerToken == "access")
        guard case .assigned(let floors, let myFloorID, let area) = summary else {
            Issue.record("배정 상태여야 한다: \(summary)")
            return
        }
        #expect(area == MyCleaningArea(
            range: "본관 계단 A",
            description: "1층→4층",
            startMinute: 7 * 60 + 20,
            endMinute: 8 * 60 + 10,
            memberNames: ["김서연", "이도윤"],
            myName: "이도윤"
        ))
        // 서버에 도면이 없어 앱 도면을 쓰고, 어느 칸이 내 구역인지 몰라 `.mine` 칸을 두지 않는다.
        #expect(floors.map(\.id) == MockCleaningAreaRepository.Fixture.floors.map(\.id))
        #expect(myFloorID == floors.first?.id)
        #expect(!floors.flatMap { $0.rows.flatMap { $0 } }.contains { $0.kind == .mine })
    }

    /// 내 정보를 받지 못했거나 구성원에 내 ID가 없으면 나를 따로 표시하지 않는다(구역은 보여 준다).
    @Test(arguments: [nil, "9"] as [String?])
    func unknownCurrentUserHasNoMyName(userID: String?) async throws {
        let user = userID.map { CurrentUser(id: $0, name: "이도윤", studentNumber: nil, grade: 2, classNumber: 3) }
        let repository = makeRepository(currentUser: user, statusCode: 200, json: Self.assignmentJSON())

        guard case .assigned(_, _, let area) = try await repository.fetchCleaningArea() else {
            Issue.record("배정 상태여야 한다")
            return
        }
        #expect(area.myName == nil)
    }

    @Test func noAssignmentIsUnassigned() async throws {
        let repository = makeRepository(statusCode: 404, json: #"{"code":"NO_ASSIGNMENT","message":"배정된 구역이 없습니다."}"#)

        #expect(try await repository.fetchCleaningArea() == .unassigned)
    }

    /// 청소 시간이 없거나 읽을 수 없으면 서버 시드 기본값(07:20~08:10)을 쓴다.
    @Test(arguments: ["null", #""아침""#])
    func unreadableCleanTimeFallsBackToDefault(cleanTime: String) async throws {
        let repository = makeRepository(statusCode: 200, json: Self.assignmentJSON(cleanTime: cleanTime))

        guard case .assigned(_, _, let area) = try await repository.fetchCleaningArea() else {
            Issue.record("배정 상태여야 한다")
            return
        }
        #expect(area.startMinute == CleaningWindow.serverDefault.startMinute)
        #expect(area.endMinute == CleaningWindow.serverDefault.endMinute)
    }

    @Test func serverErrorIsThrown() async throws {
        let repository = makeRepository(statusCode: 500, json: #"{"code":"INTERNAL_SERVER_ERROR","message":"서버 오류"}"#)

        await #expect(throws: APIError.server(statusCode: 500, code: "INTERNAL_SERVER_ERROR")) {
            try await repository.fetchCleaningArea()
        }
    }
}
