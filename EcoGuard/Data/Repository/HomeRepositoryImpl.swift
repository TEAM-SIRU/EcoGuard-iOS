import Foundation

/// 서버 홈. 홈 전용 API가 없어 구역 배정·이번 주 현황·내 인증·공지(배정 전이면 신청·모집)를 함께 불러 합친다.
final class HomeRepositoryImpl: HomeRepository {
    private let apiClient: APIClient
    private let defaults: UserDefaults
    private let now: () -> Date

    /// 서버에 공지 닫기 API가 없어 닫은 공지 ID를 기기에 둔다. 세션을 지울 때 같이 지운다(`UserDefaultsSessionUserStore`).
    nonisolated static let dismissedNoticeIDsKey = "home.dismissedNoticeIDs"

    /// 오늘 인증 정보(`GET /verifications/today`)를 기다리는 최대 시간. 지나면 기기 시각으로 보여 준다.
    private let todayInfoTimeout: Duration

    init(
        apiClient: APIClient,
        defaults: UserDefaults = .standard,
        todayInfoTimeout: Duration = .seconds(5),
        now: @escaping () -> Date = Date.init
    ) {
        self.apiClient = apiClient
        self.defaults = defaults
        self.todayInfoTimeout = todayInfoTimeout
        self.now = now
    }

    func fetchHome() async throws -> HomeSummary {
        let apiClient = apiClient
        async let assignment = Self.sendAllowingMissing(HomeDTO.Assignment.self, .Home.myAssignment, missingCode: "NO_ASSIGNMENT", apiClient: apiClient)
        // 배정된 학생이 대부분이라 배정 여부를 기다리지 않고 함께 보낸다. 배정 전이면 쓰지 않는다.
        async let weekly: WeeklyActivityResponseDTO = apiClient.send(.myWeeklyActivity)
        async let verifications: [HomeDTO.Verification] = apiClient.send(.Home.myVerifications)
        // 인증 가능 여부(방학 등). 보조 정보라 늦거나(`todayInfoTimeout`) 받지 못해도 홈은 기기 시각으로 보여 준다.
        async let todayInfo = Self.firstWithin(todayInfoTimeout) {
            try await apiClient.send(.todayVerification, as: TodayVerificationResponseDTO.self)
        }
        async let notice = latestNotice(dismissedIDs: dismissedNoticeIDs, apiClient: apiClient)

        let status: HomeStatus
        if let assignment = try await assignment {
            status = .active(try HomeMapper.activeCleaning(
                assignment: assignment,
                weekly: try await weekly,
                verifications: try await verifications,
                todayInfo: await todayInfo,
                now: now()
            ))
        } else {
            let recruitment = try await Self.sendAllowingMissing(
                HomeDTO.CurrentRecruitment.self,
                .Home.currentRecruitment,
                missingCode: "NO_ACTIVE_RECRUITMENT",
                apiClient: apiClient
            )
            // 현재 공고에 신청했을 때만 내 신청(가장 최근 신청)을 본다. 지난 공고의 신청은 이번 상태가 아니다.
            let application = recruitment?.alreadyApplied == true
                ? try await Self.sendAllowingMissing(HomeDTO.Application.self, .Home.myApplication, missingCode: "NO_APPLICATION", apiClient: apiClient)
                : nil
            status = HomeMapper.unassignedStatus(recruitment: recruitment, application: application, now: now())
        }
        return HomeSummary(status: status, notice: await notice)
    }

    func dismissNotice(id: String) async {
        defaults.set(Array(dismissedNoticeIDs.union([id])), forKey: Self.dismissedNoticeIDsKey)
    }

    private var dismissedNoticeIDs: Set<String> {
        Set(defaults.stringArray(forKey: Self.dismissedNoticeIDsKey) ?? [])
    }

    /// 닫지 않은 최신 공지. 공지는 홈 본문이 아니라서 불러오지 못해도 홈은 보여 준다(nil).
    nonisolated private func latestNotice(dismissedIDs: Set<String>, apiClient: APIClient) async -> Notice? {
        do {
            let notices: [HomeDTO.NoticeListItem] = try await apiClient.send(.Home.notices)
            guard let latest = notices.first, !dismissedIDs.contains(String(latest.noticeId)) else { return nil }
            return try latest.toHomeNotice()
        } catch {
            return nil
        }
    }

    /// `timeout` 안에 끝난 결과. 늦거나 실패하면 nil이고, 늦은 요청은 취소한다.
    nonisolated static func firstWithin<Value: Sendable>(
        _ timeout: Duration,
        _ operation: @escaping @Sendable () async throws -> Value
    ) async -> Value? {
        await withTaskGroup(of: Value?.self) { group in
            group.addTask { try? await operation() }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    /// 404이고 서버 코드가 `missingCode`면(아직 없는 데이터) nil.
    nonisolated static func sendAllowingMissing<Response: Decodable>(
        _ type: Response.Type,
        _ endpoint: Endpoint,
        missingCode: String,
        apiClient: APIClient
    ) async throws -> Response? {
        do {
            return try await apiClient.send(endpoint, as: type)
        } catch APIError.server(statusCode: 404, code: missingCode) {
            return nil
        }
    }
}
