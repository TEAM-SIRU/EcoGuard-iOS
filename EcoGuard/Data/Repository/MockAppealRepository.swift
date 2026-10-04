import Foundation

/// 서버 연동 전까지 쓰는 Mock. 내역은 Figma `09-3 이의신청 내역` (317:1018) 값을 지연 후 돌려준다.
final class MockAppealRepository: AppealRepository {
    enum Scenario: CaseIterable {
        /// Figma 내역 3건(검토 중·반려·승인).
        case history
        case empty
        case failure
    }

    enum SubmitOutcome {
        case success
        /// 서버에 닿지 않고 실패했다.
        case failure
        /// 서버는 접수했는데 응답을 받지 못했다. 다시 보내기 전에 `requestID`로 조회하면 접수된 것이 나온다.
        case failureAfterReceived
    }

    struct RequestFailedError: Error {}

    var scenario: Scenario
    /// 테스트에서 첫 호출을 붙잡아 둔 뒤 다음 호출은 바로 끝내도록 바꿀 수 있다.
    var delay: Duration
    private var submitOutcomes: [SubmitOutcome]
    private var remainingFetchFailures: Int
    /// 접수된 이의신청. 키는 `requestID`.
    private var received: [String: Appeal] = [:]
    private(set) var fetchCallCount = 0
    private(set) var statusCheckCallCount = 0
    private(set) var submitCallCount = 0
    private(set) var lastDraft: AppealDraft?

    /// - Parameters:
    ///   - submitOutcomes: 제출 결과를 차례로 쓴다. 다 쓰면 마지막 결과를 계속 쓴다.
    ///   - fetchFailuresBeforeSuccess: 내역 조회가 처음 몇 번 실패한 뒤 `scenario` 결과를 돌려준다.
    init(
        scenario: Scenario = .history,
        submitOutcomes: [SubmitOutcome] = [.success],
        fetchFailuresBeforeSuccess: Int = 0,
        delay: Duration = .seconds(1)
    ) {
        self.scenario = scenario
        self.submitOutcomes = submitOutcomes
        self.remainingFetchFailures = fetchFailuresBeforeSuccess
        self.delay = delay
    }

    func fetchAppeals() async throws -> [Appeal] {
        fetchCallCount += 1
        try await Task.sleep(for: delay)
        if remainingFetchFailures > 0 {
            remainingFetchFailures -= 1
            throw RequestFailedError()
        }
        switch scenario {
        case .history: return receivedNewestFirst + Fixture.history
        case .empty: return receivedNewestFirst
        case .failure: throw RequestFailedError()
        }
    }

    func fetchAppeal(requestID: String) async throws -> Appeal? {
        statusCheckCallCount += 1
        try await Task.sleep(for: delay)
        return received[requestID]
    }

    func submitAppeal(_ draft: AppealDraft) async throws -> Appeal {
        submitCallCount += 1
        lastDraft = draft
        try await Task.sleep(for: delay)
        let outcome = submitOutcomes.count > 1 ? submitOutcomes.removeFirst() : (submitOutcomes.first ?? .success)
        if outcome == .failure {
            throw RequestFailedError()
        }
        let appeal = received[draft.requestID] ?? Fixture.submitted(draft, round: round(for: draft.verificationID))
        received[draft.requestID] = appeal
        if outcome == .failureAfterReceived {
            throw RequestFailedError()
        }
        return appeal
    }

    private var receivedNewestFirst: [Appeal] {
        received.values.sorted { $0.submittedAt > $1.submittedAt }
    }

    private func round(for verificationID: String) -> Int {
        let previous = (scenario == .history ? Fixture.history : []) + Array(received.values)
        return previous.filter { $0.verificationID == verificationID }.count + 1
    }
}

extension MockAppealRepository {
    /// Figma `09 이의신청` 프레임에 적힌 값. 날짜는 KST.
    enum Fixture {
        static let rejectedVerificationID = "verification-20260922"
        static let approvedVerificationID = "verification-20260921"
        /// `9월 22일(화) 08:04` 인증 (317:1010).
        static let rejectedVerifiedAt = date(month: 9, day: 22, hour: 8, minute: 4)
        /// `9월 21일(월)` 인증 (514:217). 인증 시각은 Figma에 없어 같은 08:04로 둔다.
        static let approvedVerifiedAt = date(month: 9, day: 21, hour: 8, minute: 4)
        /// 작성 화면 대상 (239:282).
        static let target = AppealTarget(
            verificationID: rejectedVerificationID,
            verifiedAt: rejectedVerifiedAt,
            rejectionReason: "사진에 청소 구역이 잘 보이지 않아요"
        )
        /// 제출하면 `보낸 시각`이 된다. Figma `9월 29일(화) 12:20` (317:1013).
        static let submittedAt = date(month: 9, day: 29, hour: 12, minute: 20)

        /// 2차 · 검토 중 (317:1057).
        static let reviewing = Appeal(
            id: "appeal-3",
            verificationID: rejectedVerificationID,
            verifiedAt: rejectedVerifiedAt,
            round: 2,
            submittedAt: submittedAt,
            status: .reviewing,
            earnedMinutes: 0,
            teacherReply: nil,
            photoURL: nil
        )

        /// 1차 · 반려 (317:1084, 결과 317:1177).
        static let rejected = Appeal(
            id: "appeal-2",
            verificationID: rejectedVerificationID,
            verifiedAt: rejectedVerifiedAt,
            round: 1,
            submittedAt: date(month: 9, day: 22, hour: 13, minute: 2),
            status: .rejected,
            earnedMinutes: 0,
            teacherReply: .init(
                title: "사진에 구역 표지판이 보이지 않아요",
                message: "표지판이 보이게 다시 찍어 주세요. 08:10 이후에도 이의신청용 촬영은 가능해요."
            ),
            photoURL: nil
        )

        /// 1차 · 승인 +10분 (317:1066, 결과 514:194).
        static let approved = Appeal(
            id: "appeal-1",
            verificationID: approvedVerificationID,
            verifiedAt: approvedVerifiedAt,
            round: 1,
            submittedAt: date(month: 9, day: 21, hour: 12, minute: 40),
            status: .approved,
            earnedMinutes: 10,
            teacherReply: nil,
            photoURL: nil
        )

        static let history = [reviewing, rejected, approved]

        static func submitted(_ draft: AppealDraft, round: Int) -> Appeal {
            Appeal(
                id: "appeal-\(draft.requestID)",
                verificationID: draft.verificationID,
                verifiedAt: draft.verificationID == target.verificationID ? target.verifiedAt : approvedVerifiedAt,
                round: round,
                submittedAt: submittedAt,
                status: .reviewing,
                earnedMinutes: 0,
                teacherReply: nil,
                photoURL: nil
            )
        }

        private static func date(month: Int, day: Int, hour: Int, minute: Int) -> Date {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
            return calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
        }
    }
}
