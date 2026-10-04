import Foundation

/// 서버 연동 전까지 쓰는 Mock. 공지 목록은 Figma 디자인이 없어 홈 공지 카드 데이터를 그대로 돌려준다.
final class MockNoticeRepository: NoticeRepository {
    enum Scenario: CaseIterable {
        case loaded
        case failure
    }

    struct FetchFailedError: Error {}

    private var scenarios: [Scenario]
    private let delay: Duration
    private(set) var fetchCallCount = 0

    /// 호출마다 `scenarios`를 앞에서부터 하나씩 쓰고, 마지막 상태는 이후 호출에도 계속 쓴다.
    init(scenarios: [Scenario], delay: Duration = .seconds(1)) {
        precondition(!scenarios.isEmpty, "scenarios는 비어 있을 수 없다")
        self.scenarios = scenarios
        self.delay = delay
    }

    convenience init(scenario: Scenario = .loaded, delay: Duration = .seconds(1)) {
        self.init(scenarios: [scenario], delay: delay)
    }

    func fetchNotices() async throws -> [Notice] {
        fetchCallCount += 1
        let scenario = scenarios.count > 1 ? scenarios.removeFirst() : scenarios[0]
        try await Task.sleep(for: delay)
        switch scenario {
        case .loaded: return Fixture.notices
        case .failure: throw FetchFailedError()
        }
    }
}

extension MockNoticeRepository {
    enum Fixture {
        static let notices = [MockHomeRepository.Fixture.notice]
    }
}
