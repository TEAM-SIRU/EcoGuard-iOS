import Foundation

/// 서버 연동 전까지 쓰는 Mock. 고른 상태(Figma `03 모집 공고` · `05 신청 결과` 프레임)의 데이터를 지연 후 돌려준다.
final class MockRecruitmentRepository: RecruitmentRepository {
    enum Scenario: CaseIterable {
        case open
        case full
        case applied
        case upcoming
        case ended
        case none
        case failure
    }

    enum ApplyOutcome {
        case approved
        /// 승인됐고 청소 구역까지 배정됐다.
        case approvedAndAssigned
        case full
        case notInPeriod
        case alreadyApplied
        case failure
    }

    struct RequestFailedError: Error {}

    private var scenarios: [Scenario]
    private var applyOutcomes: [ApplyOutcome]
    private let delay: Duration
    /// 있으면 내 신청과 공고 기간을 다른 Mock과 같이 쓴다(`MockStore`).
    private let store: MockStore?
    private(set) var fetchCallCount = 0
    private(set) var applyCallCount = 0
    private(set) var fetchMyApplicationCallCount = 0
    private(set) var appliedMotivations: [String] = []

    /// 공고 조회마다 `scenarios`를, 신청마다 `applyOutcomes`를 앞에서부터 하나씩 쓰고, 마지막 값은 이후 호출에도 계속 쓴다.
    /// `store`를 주면 공고 기간은 오늘 기준이고, 내 신청은 `scenario`와 상관없이 `store`의 신청이다. 신청하면 `store`에 남는다.
    init(scenarios: [Scenario], applyOutcomes: [ApplyOutcome] = [.approved], delay: Duration = .seconds(1), store: MockStore? = nil) {
        precondition(!scenarios.isEmpty, "scenarios는 비어 있을 수 없다")
        precondition(!applyOutcomes.isEmpty, "applyOutcomes는 비어 있을 수 없다")
        self.scenarios = scenarios
        self.applyOutcomes = applyOutcomes
        self.delay = delay
        self.store = store
    }

    convenience init(scenario: Scenario = .open, applyOutcomes: [ApplyOutcome] = [.approved], delay: Duration = .seconds(1), store: MockStore? = nil) {
        self.init(scenarios: [scenario], applyOutcomes: applyOutcomes, delay: delay, store: store)
    }

    /// 지금 쓰는(마지막으로 꺼낸) 공고 상태.
    private var currentScenario: Scenario {
        scenarios[0]
    }

    func fetchRecruitment() async throws -> RecruitmentDetail? {
        fetchCallCount += 1
        if fetchCallCount > 1, scenarios.count > 1 {
            scenarios.removeFirst()
        }
        let scenario = currentScenario
        try await Task.sleep(for: delay)
        if let store, scenario != .failure {
            return Fixture.detail(scenario: scenario, store: store)
        }
        switch scenario {
        case .open: return Fixture.detail(phase: .open, appliedCount: 4)
        case .full: return Fixture.detail(phase: .open, appliedCount: 6)
        case .applied: return Fixture.detail(phase: .open, appliedCount: 4, myApplication: Fixture.application())
        case .upcoming: return Fixture.detail(phase: .upcoming, appliedCount: 0)
        case .ended: return Fixture.detail(phase: .ended, appliedCount: 5)
        case .none: return nil
        case .failure: throw RequestFailedError()
        }
    }

    /// 공고 조회와 함께 불리므로 실패는 `fetchRecruitment`에서만 낸다.
    func fetchApplicant() async throws -> Applicant {
        try await Task.sleep(for: delay)
        return Fixture.applicant
    }

    func apply(motivation: String) async throws -> RecruitmentApplication {
        applyCallCount += 1
        appliedMotivations.append(motivation)
        let outcome = applyOutcomes.count > 1 ? applyOutcomes.removeFirst() : applyOutcomes[0]
        try await Task.sleep(for: delay)
        if let store {
            let appliedCount = Fixture.detail(scenario: currentScenario, store: store)?.recruitment.appliedCount ?? 0
            switch outcome {
            case .approved: return store.recordApplication(appliedCount: appliedCount, isAreaAssigned: false)
            case .approvedAndAssigned: return store.recordApplication(appliedCount: appliedCount, isAreaAssigned: true)
            case .alreadyApplied: throw RecruitmentError.alreadyApplied(store.application ?? Fixture.application())
            case .full, .notInPeriod, .failure: break
            }
        }
        switch outcome {
        case .approved: return Fixture.application()
        case .approvedAndAssigned: return Fixture.application(isAreaAssigned: true)
        case .full: throw RecruitmentError.full
        case .notInPeriod: throw RecruitmentError.notInPeriod
        case .alreadyApplied: throw RecruitmentError.alreadyApplied(Fixture.application())
        case .failure: throw RequestFailedError()
        }
    }

    func fetchMyApplication() async throws -> RecruitmentApplication? {
        fetchMyApplicationCallCount += 1
        try await Task.sleep(for: delay)
        switch currentScenario {
        case .failure: throw RequestFailedError()
        case _ where store != nil: return store?.application
        case .applied: return Fixture.application()
        default: return nil
        }
    }
}

extension MockRecruitmentRepository {
    /// Figma `03 모집 공고` 프레임에 적힌 값. 날짜는 학교 시간대(KST) 기준이다.
    enum Fixture {
        static let calendar: Calendar = {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
            return calendar
        }()

        static let applicant = Applicant(studentNumber: "2310", name: "최민준")

        /// `store`의 오늘 기준 공고. 내 신청은 `store`의 신청이고, 신청 인원에는 내가 이번에 낸 신청도 들어간다.
        static func detail(scenario: Scenario, store: MockStore) -> RecruitmentDetail? {
            let (phase, appliedCount): (RecruitmentDetail.Phase, Int)
            switch scenario {
            case .open, .applied: (phase, appliedCount) = (.open, 4)
            case .full: (phase, appliedCount) = (.open, 6)
            case .upcoming: (phase, appliedCount) = (.upcoming, 0)
            case .ended: (phase, appliedCount) = (.ended, 5)
            case .none, .failure: return nil
            }
            let period = MockStore.recruitmentPeriod(phase, now: store.now())
            return detail(
                phase: phase,
                appliedCount: max(appliedCount, store.application?.order ?? 0),
                myApplication: store.application,
                startDate: period.start,
                endDate: period.end
            )
        }

        static func detail(
            phase: RecruitmentDetail.Phase,
            appliedCount: Int,
            myApplication: RecruitmentApplication? = nil,
            startDate: Date = date(month: 9, day: 1),
            endDate: Date = date(month: 9, day: 4, hour: 23, minute: 59)
        ) -> RecruitmentDetail {
            RecruitmentDetail(
                recruitment: Recruitment(semester: 2, capacityPerClass: 6, className: "2학년 3반", appliedCount: appliedCount),
                startDate: startDate,
                endDate: endDate,
                activityWindow: CleaningWindow(startMinute: 8 * 60, endMinute: 8 * 60 + 10),
                phase: phase,
                myApplication: myApplication
            )
        }

        /// Figma `9월 1일(화) 12:34에 4번째로 신청했어요`.
        static func application(isAreaAssigned: Bool = false) -> RecruitmentApplication {
            RecruitmentApplication(order: 4, appliedAt: date(month: 9, day: 1, hour: 12, minute: 34), isAreaAssigned: isAreaAssigned)
        }

        /// Figma 공고 날짜(2026년). 시나리오만 고른 Mock(테스트)이 쓴다.
        static func date(month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
            let components = DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)
            return calendar.date(from: components) ?? .distantPast
        }
    }
}
