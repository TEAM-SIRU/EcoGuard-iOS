import Foundation
@testable import EcoGuard

/// 취소 테스트용 게이트. 처음 `holdCount`번 호출은 취소될 때까지 끝나지 않고, 그 뒤 호출은 바로 지나간다.
/// 고정 지연은 부하가 크면 취소하기 전에 응답이 끝나 테스트가 흔들린다. 게이트에 걸린 호출은 응답이 취소보다 먼저 올 수 없다.
@MainActor
final class CancellationGate {
    private let holdCount: Int
    private(set) var callCount = 0

    init(holding holdCount: Int = 1) {
        self.holdCount = holdCount
    }

    func pass() async throws {
        callCount += 1
        guard callCount <= holdCount else { return }
        while true {
            try await Task.sleep(for: .seconds(60))
        }
    }

    /// 게이트에 걸린 호출이 시작될 때까지 기다린다. 이 뒤에 취소하면 항상 응답 전에 취소된다.
    func waitForHeldCall() async {
        while callCount < holdCount {
            await Task.yield()
        }
    }
}

/// 공지 목록 조회 앞에 게이트를 둔 Mock. 응답은 지연 없는 `MockNoticeRepository`가 만든다.
@MainActor
final class GatedNoticeRepository: NoticeRepository {
    let gate: CancellationGate
    let base: MockNoticeRepository

    init(scenarios: [MockNoticeRepository.Scenario]) {
        gate = CancellationGate()
        base = MockNoticeRepository(scenarios: scenarios, delay: .zero)
    }

    func fetchNotices() async throws -> [Notice] {
        try await gate.pass()
        return try await base.fetchNotices()
    }

    func fetchNotice(id: Notice.ID) async throws -> Notice? {
        try await base.fetchNotice(id: id)
    }
}

/// 고른 메서드 앞에 게이트를 둔 Mock. 응답은 지연 없는 `MockRecruitmentRepository`가 만든다.
@MainActor
final class GatedRecruitmentRepository: RecruitmentRepository {
    enum Method {
        case fetchRecruitment
        case apply
        case fetchMyApplication
    }

    let gate: CancellationGate
    let base: MockRecruitmentRepository
    private let gatedMethod: Method

    init(
        gating gatedMethod: Method,
        scenario: MockRecruitmentRepository.Scenario = .open,
        applyOutcomes: [MockRecruitmentRepository.ApplyOutcome] = [.approved]
    ) {
        self.gatedMethod = gatedMethod
        gate = CancellationGate()
        base = MockRecruitmentRepository(scenario: scenario, applyOutcomes: applyOutcomes, delay: .zero)
    }

    func fetchRecruitment() async throws -> RecruitmentDetail? {
        try await pass(.fetchRecruitment)
        return try await base.fetchRecruitment()
    }

    func fetchApplicant() async throws -> Applicant {
        try await base.fetchApplicant()
    }

    func apply(motivation: String) async throws -> RecruitmentApplication {
        try await pass(.apply)
        return try await base.apply(motivation: motivation)
    }

    func fetchMyApplication() async throws -> RecruitmentApplication? {
        try await pass(.fetchMyApplication)
        return try await base.fetchMyApplication()
    }

    private func pass(_ method: Method) async throws {
        guard method == gatedMethod else { return }
        try await gate.pass()
    }
}

/// 홈 조회 앞에 게이트를 둔 저장소. 응답은 `base`(지연 없는 Mock)가 만든다.
@MainActor
final class GatedHomeRepository: HomeRepository {
    let gate = CancellationGate()
    let base: HomeRepository

    init(base: HomeRepository) {
        self.base = base
    }

    func fetchHome() async throws -> HomeSummary {
        try await gate.pass()
        return try await base.fetchHome()
    }

    func dismissNotice(id: String) async {
        await base.dismissNotice(id: id)
    }
}

/// 월 기록 조회 앞에 게이트를 둔 저장소. 응답은 `base`(지연 없는 Mock)가 만든다.
@MainActor
final class GatedActivityRepository: ActivityRepository {
    let gate = CancellationGate()
    let base: ActivityRepository

    init(base: ActivityRepository) {
        self.base = base
    }

    func fetchMonth(year: Int, month: Int) async throws -> ActivityMonth {
        try await gate.pass()
        return try await base.fetchMonth(year: year, month: month)
    }
}
