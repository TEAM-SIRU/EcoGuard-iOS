import Foundation

/// 이의신청. 서버는 내용만 받는다(사진·`requestID` 없음).
final class AppealRepositoryImpl: AppealRepository {
    private let apiClient: APIClient
    /// 이 저장소로 보내기 시작한 `requestID`와 대상 인증. 서버에 `requestID`가 없어 접수 여부를 대상 인증으로 찾는다.
    private var attemptedVerificationIDs: [String: String] = [:]

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchAppeals() async throws -> [Appeal] {
        let response: [MyAppealResponseDTO] = try await apiClient.send(.myAppeals)
        return try response.map { try $0.appeal }
    }

    /// 같은 인증에는 검토 중인 이의신청이 하나만 있을 수 있다(서버 `APPEAL_ALREADY_PENDING`).
    /// 그래서 이 `requestID`로 보낸 인증에 검토 중인 이의신청이 있으면 그것이 앞서 보낸 제출이다.
    func fetchAppeal(requestID: String) async throws -> Appeal? {
        guard let verificationID = attemptedVerificationIDs[requestID] else { return nil }
        return try await fetchAppeals().first { $0.verificationID == verificationID && $0.status == .reviewing }
    }

    /// 접수 응답에는 회차·상태뿐이라 내역을 다시 받아 완료 화면에 쓸 값(보낸 시각 등)을 채운다.
    /// 다시 받다가 실패하면 에러를 던지고, 다음 제출에서 `fetchAppeal(requestID:)`로 접수된 것을 찾는다.
    func submitAppeal(_ draft: AppealDraft) async throws -> Appeal {
        attemptedVerificationIDs[draft.requestID] = draft.verificationID
        let created: CreateAppealResponseDTO = try await apiClient.send(
            .createAppeal(verificationID: draft.verificationID, content: draft.message)
        )
        guard let appeal = try await fetchAppeals().first(where: { $0.id == String(created.appealId) }) else {
            throw APIError.invalidResponse
        }
        return appeal
    }
}
