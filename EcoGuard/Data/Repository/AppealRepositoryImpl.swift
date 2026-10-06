import Foundation

/// 이의신청. 서버에 `requestID`가 없어 접수 여부를 대상 인증으로 찾는다.
final class AppealRepositoryImpl: AppealRepository {
    private let apiClient: APIClient
    /// 이 저장소로 보내기 시작한 `requestID`와 대상 인증. 서버에 `requestID`가 없어 접수 여부를 대상 인증으로 찾는다.
    private var attemptedVerificationIDs: [String: String] = [:]

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchAppeals() async throws -> [Appeal] {
        let response: [MyAppealResponseDTO] = try await apiClient.send(.myAppeals)
        let baseURL = apiClient.httpClient.baseURL
        return try response.map { try $0.appeal(baseURL: baseURL) }
    }

    /// 같은 인증에는 검토 중인 이의신청이 하나만 있을 수 있다(서버 `APPEAL_ALREADY_PENDING`).
    /// 그래서 이 `requestID`로 보낸 인증에 검토 중인 이의신청이 있으면 그것이 앞서 보낸 제출이다.
    func fetchAppeal(requestID: String) async throws -> Appeal? {
        guard let verificationID = attemptedVerificationIDs[requestID] else { return nil }
        return try await fetchAppeals().first { $0.verificationID == verificationID && $0.status == .reviewing }
    }

    /// 사진 바디는 `Endpoint`가 완성된 `Data`로 들고 있어 401 재발급 뒤에도 같은 바디를 다시 보낸다.
    /// 접수 응답에는 회차·상태뿐이라 내역을 다시 받아 완료 화면에 쓸 값(보낸 시각 등)을 채운다.
    /// 다시 받다가 실패하면 에러를 던지고, 다음 제출에서 `fetchAppeal(requestID:)`로 접수된 것을 찾는다.
    func submitAppeal(_ draft: AppealDraft) async throws -> Appeal {
        attemptedVerificationIDs[draft.requestID] = draft.verificationID
        let created: CreateAppealResponseDTO
        do {
            created = try await apiClient.send(.createAppeal(
                verificationID: draft.verificationID,
                content: draft.message,
                jpegPhotos: draft.photos.map(\.jpegData)
            ))
        } catch let error as APIError where error == .server(statusCode: 409, code: "APPEAL_ALREADY_PENDING") {
            // 검토 중인 이의신청을 찾지 못하면(그새 처리됨) 서버 오류 그대로 올린다.
            let appeals = try? await fetchAppeals()
            guard let pending = appeals?.first(where: { $0.verificationID == draft.verificationID && $0.status == .reviewing }) else {
                throw error
            }
            throw AppealError.alreadyPending(pending)
        }
        guard let appeal = try await fetchAppeals().first(where: { $0.id == String(created.appealId) }) else {
            throw APIError.invalidResponse
        }
        return appeal
    }
}
