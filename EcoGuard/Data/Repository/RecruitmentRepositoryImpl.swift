import Foundation

/// 서버 모집·신청. 신청 API가 공고 ID를 받으므로 마지막으로 조회한 공고 ID를 들고 있는다.
final class RecruitmentRepositoryImpl: RecruitmentRepository {
    /// 공고에 활동 시간이 없어 쓰는 기본값. 서버 청소 구역 시드의 `clean-time: "07:20~08:10"`.
    static let defaultActivityWindow = CleaningWindow(startMinute: 7 * 60 + 20, endMinute: 8 * 60 + 10)

    private let apiClient: APIClient
    private let activityWindow: CleaningWindow
    private let now: () -> Date
    private var recruitmentID: Int64?

    init(apiClient: APIClient, activityWindow: CleaningWindow = defaultActivityWindow, now: @escaping () -> Date = Date.init) {
        self.apiClient = apiClient
        self.activityWindow = activityWindow
        self.now = now
    }

    func fetchRecruitment() async throws -> RecruitmentDetail? {
        let response: CurrentRecruitmentResponseDTO
        do {
            response = try await apiClient.send(.currentRecruitment)
        } catch let error as APIError where error == .server(statusCode: 404, code: "NO_ACTIVE_RECRUITMENT") {
            recruitmentID = nil
            return nil
        }
        recruitmentID = response.recruitmentId
        // 공고에는 신청 여부만 있어 순서·배정 여부는 내 신청에서 받는다.
        let myApplication = response.alreadyApplied ? try await fetchMyApplication() : nil
        return try response.toDomain(activityWindow: activityWindow, myApplication: myApplication)
    }

    // TODO: 서버에 내 정보 API(학번·이름)가 생기면 바꾼다. 그 전까지 Mock 값을 보여 준다.
    func fetchApplicant() async throws -> Applicant {
        MockRecruitmentRepository.Fixture.applicant
    }

    func apply(motivation: String) async throws -> RecruitmentApplication {
        let recruitmentID = try await currentRecruitmentID()
        do {
            let response: ApplyResponseDTO = try await apiClient.send(.apply(recruitmentID: recruitmentID, motivation: motivation))
            return response.toDomain(receivedAt: now())
        } catch let error as APIError {
            throw try await recruitmentError(for: error)
        }
    }

    func fetchMyApplication() async throws -> RecruitmentApplication? {
        do {
            let response: ApplicationStatusResponseDTO = try await apiClient.send(.myApplication)
            // TODO: 서버가 신청 시각을 내려주면 대체값을 뺀다. 그 전까지 조회 시각을 보여 준다.
            return try response.toDomain(fallbackAppliedAt: now())
        } catch let error as APIError where error == .server(statusCode: 404, code: "NO_APPLICATION") {
            return nil
        }
    }

    /// 공고 화면을 거치지 않고 신청하면(다시 열린 화면 등) 공고를 먼저 조회한다.
    private func currentRecruitmentID() async throws -> Int64 {
        if let recruitmentID { return recruitmentID }
        guard try await fetchRecruitment() != nil, let recruitmentID else { throw RecruitmentError.notInPeriod }
        return recruitmentID
    }

    /// 서버 `ErrorCode` → `RecruitmentError`. 해당하지 않으면 원래 에러를 그대로 던진다.
    private func recruitmentError(for error: APIError) async throws -> Error {
        switch error {
        case .server(statusCode: 400, code: "OUT_OF_PERIOD"):
            return RecruitmentError.notInPeriod
        case .server(statusCode: 409, code: "RECRUITMENT_FULL"):
            return RecruitmentError.full
        case .server(statusCode: 409, code: "ALREADY_APPLIED"):
            // 화면이 기존 신청을 보여 주므로 내 신청을 받아 함께 넘긴다.
            guard let application = try await fetchMyApplication() else { return error }
            return RecruitmentError.alreadyApplied(application)
        default:
            return error
        }
    }
}
