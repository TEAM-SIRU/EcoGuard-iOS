import Foundation

/// 청소 인증 사진 제출. 인증 가능 여부·마감·서버 시각은 오늘 인증 정보(`/verifications/today`)로 받는다.
final class VerificationRepositoryImpl: VerificationRepository {
    private let apiClient: APIClient
    private let now: () -> Date

    init(apiClient: APIClient, now: @escaping () -> Date = Date.init) {
        self.apiClient = apiClient
        self.now = now
    }

    func fetchSession() async throws -> VerificationSession {
        let today: TodayVerificationResponseDTO = try await apiClient.send(.todayVerification)
        return try today.session()
    }

    /// 사진 ID를 재전송 키로 보내 같은 사진의 재시도는 서버가 처음 접수 결과를 돌려준다.
    func submit(_ photo: VerificationPhoto) async throws -> VerificationSubmission {
        let endpoint = Endpoint.submitVerification(
            photoID: photo.id,
            jpegData: photo.jpegData,
            startedAt: photo.uploadStartedAt ?? now()
        )
        let (data, response) = try await apiClient.response(for: endpoint)
        do {
            let created = try APIClient.decode(SubmitVerificationResponseDTO.self, from: HTTPClient.validate(data, response))
            return VerificationSubmission(
                id: String(created.verificationId),
                submittedAt: try ServerDate.requiredDateTime(created.submittedAt)
            )
        } catch APIError.server(_, "ALREADY_SUBMITTED_TODAY"?) {
            // 다른 사진(다른 키)이 오늘 이미 접수됐다. 제출 시각은 에러 바디에, 검수 상태는 오늘 인증 정보에 있다.
            let error = try? APIClient.decode(SubmitVerificationErrorDTO.self, from: data)
            let today: TodayVerificationResponseDTO? = try? await apiClient.send(.todayVerification)
            throw VerificationError.alreadySubmitted(
                submittedAt: (error?.submittedAt ?? today?.submittedAt).flatMap(ServerDate.dateTime),
                status: today?.status.flatMap(VerificationStatusDTO.init(rawValue:))?.status
            )
        } catch APIError.server(_, "OUT_OF_CERTIFICATION_TIME"?) {
            // 인증 시간 밖·주말, 마감 전에 시작하지 않았거나 유예 시간이 지난 재시도가 같은 코드로 온다.
            throw VerificationError.deadlinePassed
        } catch APIError.server(_, "VACATION_PERIOD"?) {
            throw VerificationError.vacation
        }
    }
}
