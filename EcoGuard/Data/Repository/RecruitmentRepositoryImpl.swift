import Foundation

/// 서버 모집·신청. 신청 API가 공고 ID를 받으므로 마지막으로 조회한 공고 ID를 들고 있는다.
///
/// `GET /applications/me`는 공고와 상관없이 가장 최근 신청을 준다. 지난 모집의 신청을 이번 결과로 보이지 않게
/// 현재 공고의 `alreadyApplied`가 true일 때만 쓴다.
final class RecruitmentRepositoryImpl: RecruitmentRepository {
    private let apiClient: APIClient
    private let activityWindow: CleaningWindow
    private let now: () -> Date
    private var recruitmentID: Int64?

    /// 공고에 활동 시간이 없어 `activityWindow`는 서버 청소 구역 시드 값을 기본으로 쓴다.
    init(apiClient: APIClient, activityWindow: CleaningWindow = .serverDefault, now: @escaping () -> Date = Date.init) {
        self.apiClient = apiClient
        self.activityWindow = activityWindow
        self.now = now
    }

    func fetchRecruitment() async throws -> RecruitmentDetail? {
        guard let response = try await fetchCurrent() else { return nil }
        // 공고에는 신청 여부만 있어 순서·배정 여부는 내 신청에서 받는다.
        let myApplication = response.alreadyApplied ? try await fetchLatestApplication() : nil
        return try response.toDomain(activityWindow: activityWindow, myApplication: myApplication)
    }

    // TODO: 서버에 내 정보 API(학번·이름)가 생기면 바꾼다. 그 전까지 Mock 값을 보여 준다.
    func fetchApplicant() async throws -> Applicant {
        MockRecruitmentRepository.Fixture.applicant
    }

    func apply(motivation: String) async throws -> RecruitmentApplication {
        let isCached = self.recruitmentID != nil
        let recruitmentID = try await currentRecruitmentID()
        do {
            return try await send(motivation: motivation, recruitmentID: recruitmentID)
        } catch let error as APIError where isCached && Self.mayBeStaleRecruitment(error) {
            // 들고 있던 공고가 그새 바뀌었을 수 있다(새 모집 시작 등). 다시 조회해 공고가 바뀌었으면 한 번만 다시 보낸다.
            // 방금 조회한 공고면 다시 조회하지 않는다.
            guard try await fetchCurrent() != nil, let refreshedID = self.recruitmentID, refreshedID != recruitmentID else {
                throw try await recruitmentError(for: error)
            }
            do {
                return try await send(motivation: motivation, recruitmentID: refreshedID)
            } catch let error as APIError {
                throw try await recruitmentError(for: error)
            }
        } catch let error as APIError {
            throw try await recruitmentError(for: error)
        }
    }

    /// 현재 공고에 한 신청. 현재 공고가 없거나 신청하지 않았으면 nil.
    func fetchMyApplication() async throws -> RecruitmentApplication? {
        guard let current = try await fetchCurrent(), current.alreadyApplied else { return nil }
        return try await fetchLatestApplication()
    }

    /// 현재 공고. 없으면 nil. 신청에 쓸 공고 ID를 갱신한다.
    private func fetchCurrent() async throws -> CurrentRecruitmentResponseDTO? {
        do {
            let response: CurrentRecruitmentResponseDTO = try await apiClient.send(.currentRecruitment)
            recruitmentID = response.recruitmentId
            return response
        } catch let error as APIError where error == .server(statusCode: 404, code: "NO_ACTIVE_RECRUITMENT") {
            recruitmentID = nil
            return nil
        }
    }

    /// 가장 최근 신청. 현재 공고에 신청한 것이 확인됐을 때만 부른다. 반려(앱에 없는 상태)면 nil.
    // TODO: 서버가 `recruitmentId`를 내려주면 현재 공고의 신청인지 직접 확인한다(서버 요청 목록).
    private func fetchLatestApplication() async throws -> RecruitmentApplication? {
        do {
            let response: ApplicationStatusResponseDTO = try await apiClient.send(.myApplication)
            // TODO: 서버가 신청 시각을 내려주면 대체값을 뺀다. 그 전까지 조회 시각을 보여 준다.
            return try response.toDomain(fallbackAppliedAt: now())
        } catch let error as APIError where error == .server(statusCode: 404, code: "NO_APPLICATION") {
            return nil
        }
    }

    private func send(motivation: String, recruitmentID: Int64) async throws -> RecruitmentApplication {
        let response: ApplyResponseDTO = try await apiClient.send(.apply(recruitmentID: recruitmentID, motivation: motivation))
        return response.toDomain(receivedAt: now())
    }

    /// 공고 화면을 거치지 않고 신청하면(다시 열린 화면 등) 공고를 먼저 조회한다.
    private func currentRecruitmentID() async throws -> Int64 {
        if let recruitmentID { return recruitmentID }
        guard try await fetchCurrent() != nil, let recruitmentID else { throw RecruitmentError.notInPeriod }
        return recruitmentID
    }

    /// 들고 있던 공고 ID가 낡았으면 날 수 있는 에러.
    private static func mayBeStaleRecruitment(_ error: APIError) -> Bool {
        switch error {
        case .server(statusCode: 400, code: "OUT_OF_PERIOD"),
             .server(statusCode: 409, code: "RECRUITMENT_FULL"),
             .server(statusCode: 409, code: "ALREADY_APPLIED"),
             .server(statusCode: 404, code: "RECRUITMENT_NOT_FOUND"):
            true
        default:
            false
        }
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
            // 보여 줄 신청이 없으면(반려 등) 다시 신청할 수 없으므로 마감으로 알린다. 같은 실패를 반복하지 않게 한다.
            guard let application = try await fetchLatestApplication() else { return RecruitmentError.full }
            return RecruitmentError.alreadyApplied(application)
        default:
            return error
        }
    }
}
