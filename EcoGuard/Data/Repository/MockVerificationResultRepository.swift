import Foundation

/// 서버 연동 전까지 쓰는 Mock. 고른 상태(Figma `08 인증 결과` 프레임)의 결과를 지연 후 돌려준다.
final class MockVerificationResultRepository: VerificationResultRepository {
    enum Scenario: CaseIterable {
        case processing
        case approved
        case rejected
        case manualReview
        case failure
    }

    struct FetchFailedError: Error {}

    private let scenario: Scenario
    private let delay: Duration
    private let error: Error
    private var remainingFailures: Int
    private(set) var fetchCallCount = 0

    /// - Parameters:
    ///   - failuresBeforeSuccess: 처음 몇 번은 `error`로 실패한 뒤 `scenario` 결과를 돌려준다. 재시도 흐름에 쓴다.
    ///   - error: `.failure`와 `failuresBeforeSuccess`에서 던질 오류.
    init(
        scenario: Scenario = .approved,
        delay: Duration = .seconds(1),
        failuresBeforeSuccess: Int = 0,
        error: Error = FetchFailedError()
    ) {
        self.scenario = scenario
        self.delay = delay
        self.remainingFailures = failuresBeforeSuccess
        self.error = error
    }

    func fetchResult(id: String) async throws -> VerificationResult {
        fetchCallCount += 1
        try await Task.sleep(for: delay)
        if remainingFailures > 0 {
            remainingFailures -= 1
            throw error
        }
        switch scenario {
        case .processing: return Fixture.result(id: id, status: .processing)
        case .approved: return Fixture.result(id: id, status: .approved)
        case .rejected: return Fixture.result(id: id, status: .rejected)
        case .manualReview: return Fixture.result(id: id, status: .manualReview)
        case .failure: throw error
        }
    }
}

extension MockVerificationResultRepository {
    /// Figma `08 인증 결과` · `08 인증 상세` 프레임에 적힌 값.
    enum Fixture {
        static let id = "verification-20260929"
        static let area = "본관 2층 복도 A"
        static let earnedMinutes = 10
        /// Figma `사진에 청소 구역이 잘 보이지 않아요` (239:260) · `복도 끝까지 보이도록 …` (239:261).
        static let rejectionReason = VerificationResult.RejectionReason(
            title: "사진에 청소 구역이 잘 보이지 않아요",
            guide: "복도 끝까지 보이도록 조금 뒤에서 찍으면 돼요"
        )
        /// Figma `08:04` (2026-09-29 KST).
        static let submittedAt: Date = {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
            return calendar.date(from: DateComponents(year: 2026, month: 9, day: 29, hour: 8, minute: 4)) ?? .distantPast
        }()

        /// 사진은 서버 연동 전이라 비워 두고 자리표시를 그린다.
        static func result(
            id: String = id,
            status: VerificationResult.Status,
            submittedAt: Date = submittedAt
        ) -> VerificationResult {
            VerificationResult(
                id: id,
                submittedAt: submittedAt,
                area: area,
                status: status,
                rejectionReason: status == .rejected ? rejectionReason : nil,
                earnedMinutes: status == .approved ? earnedMinutes : 0,
                photoURL: nil
            )
        }
    }
}
