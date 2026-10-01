import Foundation

/// 서버 연동 전까지 쓰는 Mock. 고른 상태(Figma `06 청소 인증` 프레임)의 데이터를 지연 후 돌려준다.
/// 마감 판단은 서버 몫이라 Mock이 `now`(서버 시계)와 마감 시각으로 흉내 낸다.
final class MockVerificationRepository: VerificationRepository {
    enum Scenario: CaseIterable {
        case open
        case outsideWindow
        case alreadySubmitted
        case failure
    }

    enum UploadResult {
        case success
        case networkFailure
    }

    struct FetchFailedError: Error {}
    struct UploadFailedError: Error {}

    private let scenario: Scenario
    private var uploadResults: [UploadResult]
    private let delay: Duration
    private let now: () -> Date
    private let deadline: Date
    /// 마감 전에 보내기 시작한 사진. 마감 후에도 같은 사진의 재시도는 받는다.
    private var startedPhotoIDs: Set<UUID> = []
    private var acceptedSubmission: (photoID: UUID, submission: VerificationSubmission)?
    private(set) var fetchCallCount = 0
    private(set) var submittedPhotoIDs: [UUID] = []

    /// 업로드마다 `uploadResults`를 앞에서부터 하나씩 쓰고, 마지막 결과는 이후 호출에도 계속 쓴다.
    init(
        scenario: Scenario = .open,
        uploadResults: [UploadResult] = [.success],
        delay: Duration = .seconds(1),
        now: @escaping () -> Date = Date.init,
        deadline: Date? = nil
    ) {
        precondition(!uploadResults.isEmpty, "uploadResults는 비어 있을 수 없다")
        self.scenario = scenario
        self.uploadResults = uploadResults
        self.delay = delay
        self.now = now
        self.deadline = deadline ?? now().addingTimeInterval(Fixture.remainingUntilDeadline)
    }

    func fetchSession() async throws -> VerificationSession {
        fetchCallCount += 1
        try await Task.sleep(for: delay)
        let serverNow = now()
        if let acceptedSubmission {
            return Fixture.session(.alreadySubmitted(submittedAt: acceptedSubmission.submission.submittedAt), serverNow: serverNow)
        }
        switch scenario {
        case .open:
            return Fixture.session(serverNow < deadline ? .open(deadline: deadline) : .outsideWindow, serverNow: serverNow)
        case .outsideWindow:
            return Fixture.session(.outsideWindow, serverNow: serverNow)
        case .alreadySubmitted:
            return Fixture.session(.alreadySubmitted(submittedAt: Fixture.submittedAt), serverNow: serverNow)
        case .failure:
            throw FetchFailedError()
        }
    }

    func submit(_ photo: VerificationPhoto) async throws -> VerificationSubmission {
        submittedPhotoIDs.append(photo.id)
        if let acceptedSubmission {
            // 응답을 받지 못해 같은 사진을 다시 보낸 경우 처음 제출을 그대로 돌려준다.
            guard acceptedSubmission.photoID == photo.id else {
                throw VerificationError.alreadySubmitted(submittedAt: acceptedSubmission.submission.submittedAt)
            }
            return acceptedSubmission.submission
        }
        if scenario == .alreadySubmitted {
            throw VerificationError.alreadySubmitted(submittedAt: Fixture.submittedAt)
        }
        guard now() < deadline || startedPhotoIDs.contains(photo.id) else {
            throw VerificationError.deadlinePassed
        }
        startedPhotoIDs.insert(photo.id)
        let result = uploadResults.count > 1 ? uploadResults.removeFirst() : uploadResults[0]
        try await Task.sleep(for: delay)
        switch result {
        case .success:
            let submission = VerificationSubmission(submittedAt: now())
            acceptedSubmission = (photo.id, submission)
            return submission
        case .networkFailure:
            throw UploadFailedError()
        }
    }
}

extension MockVerificationRepository {
    /// Figma `06 청소 인증` 프레임에 적힌 값.
    enum Fixture {
        static let area = "본관 2층 복도 A"
        static let window = CleaningWindow(startMinute: 8 * 60, endMinute: 8 * 60 + 10)
        /// Figma `남은 시간 05:32`.
        static let remainingUntilDeadline: TimeInterval = 5 * 60 + 32
        /// Figma `오늘 08:04` (2026-09-29 KST).
        static let submittedAt: Date = {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
            return calendar.date(from: DateComponents(year: 2026, month: 9, day: 29, hour: 8, minute: 4)) ?? .distantPast
        }()

        static func session(_ availability: VerificationAvailability, serverNow: Date) -> VerificationSession {
            VerificationSession(area: area, window: window, availability: availability, serverNow: serverNow)
        }
    }
}
