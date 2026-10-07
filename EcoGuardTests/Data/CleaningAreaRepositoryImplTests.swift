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

    /// 서버 #24 이후 실제 응답 형태. 좌표 없이 `zoneCode`가 온다.
    private static func assignmentJSON(cleanTime: String = #""07:20~08:10""#, zoneCode: String = #""zoneCode":"main_stair_a","#) -> String {
        """
        {"areaId":3,\(zoneCode)"areaName":"본관 계단 A","description":"1층→4층","cleanTime":\(cleanTime),
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
            zoneCode: .mainStairA,
            range: "본관 계단 A",
            description: "1층→4층",
            startMinute: 7 * 60 + 20,
            endMinute: 8 * 60 + 10,
            memberNames: ["김서연", "이도윤"],
            myName: "이도윤"
        ))
        // 서버에 도면이 없어 앱 도면을 쓰고, 계단 A 칸을 1~4층 모두 내 구역으로 표시한다.
        #expect(floors.map(\.id) == SchoolFloorPlan.floors.map(\.id))
        #expect(myFloorID == "1F")
        for floor in floors {
            let mine = floor.rows.joined().filter { $0.kind == .mine }
            #expect(mine.map(\.zoneCode) == [.mainStairA], "\(floor.name)")
        }
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

    /// 앱이 모르는 구역 코드도 실패하지 않고 그대로 둔다. 코드가 없어도 구역은 보여 주고, 도면은 하이라이트 없이 첫 층을 연다.
    @Test(arguments: [
        (#""zoneCode":"annex_corridor_f9","#, CleaningZoneCode(rawValue: "annex_corridor_f9")),
        (#""zoneCode":null,"#, nil),
        ("", nil),
    ] as [(String, CleaningZoneCode?)])
    func zoneCodeIsKeptAsReceived(zoneCode: String, expected: CleaningZoneCode?) async throws {
        let repository = makeRepository(statusCode: 200, json: Self.assignmentJSON(zoneCode: zoneCode))

        guard case .assigned(let floors, let myFloorID, let area) = try await repository.fetchCleaningArea() else {
            Issue.record("배정 상태여야 한다")
            return
        }
        #expect(area.zoneCode == expected)
        #expect(floors == SchoolFloorPlan.floors)
        #expect(myFloorID == "1F")
    }

    /// 서버 구역 시드의 18개 코드를 모두 상수로 둔다.
    @Test func knownZoneCodesMatchServerSeed() {
        #expect(CleaningZoneCode.all.count == 18)
        #expect(Set(CleaningZoneCode.all).count == 18)
        #expect(CleaningZoneCode.all.first?.rawValue == "main_stair_a")
        #expect(CleaningZoneCode.all.last?.rawValue == "connector_f3")
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
