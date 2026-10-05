import Foundation

/// 청소 인증 사진 제출. 서버에 오늘 인증 정보(구역·인증 시간·서버 시각·제출 여부) API가 없어 `fetchSession`은 `sessionSource`(Mock)를 쓴다.
final class VerificationRepositoryImpl: VerificationRepository {
    private let apiClient: APIClient
    private let sessionSource: VerificationRepository
    private let now: () -> Date
    /// 보내기 시작했지만 응답을 받지 못한 사진. 같은 사진을 다시 보냈을 때 `오늘 이미 제출`이 오면 앞선 전송이 접수된 것이다.
    private var unconfirmedPhotoIDs: Set<UUID> = []

    init(apiClient: APIClient, sessionSource: VerificationRepository, now: @escaping () -> Date = Date.init) {
        self.apiClient = apiClient
        self.sessionSource = sessionSource
        self.now = now
    }

    func fetchSession() async throws -> VerificationSession {
        try await sessionSource.fetchSession()
    }

    /// 서버는 제출 시각을 주지 않아 응답을 받은 시각을 제출 시각으로 쓴다.
    func submit(_ photo: VerificationPhoto) async throws -> VerificationSubmission {
        let isRetry = unconfirmedPhotoIDs.contains(photo.id)
        unconfirmedPhotoIDs.insert(photo.id)
        do {
            let _: SubmitVerificationResponseDTO = try await apiClient.send(
                .submitVerification(photoID: photo.id, jpegData: photo.jpegData)
            )
        } catch APIError.server(_, "ALREADY_SUBMITTED_TODAY"?) {
            // 서버에 재전송 식별자가 없어, 같은 사진의 재시도면 앞선 전송이 접수된 것으로 본다.
            guard isRetry else { throw VerificationError.alreadySubmitted(submittedAt: now()) }
        } catch APIError.server(_, "OUT_OF_CERTIFICATION_TIME"?) {
            // 인증 시간 밖·주말·방학이 같은 코드로 온다.
            throw VerificationError.deadlinePassed
        }
        unconfirmedPhotoIDs.remove(photo.id)
        return VerificationSubmission(submittedAt: now())
    }
}
