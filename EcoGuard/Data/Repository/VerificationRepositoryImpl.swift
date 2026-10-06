import Foundation

/// 청소 인증 사진 제출. 서버에 오늘 인증 정보(구역·인증 시간·마감·서버 시각) API가 없어
/// 구역·인증 시간은 `sessionSource`(Mock)에서, 오늘 제출 여부는 내 인증 목록에서 가져온다.
final class VerificationRepositoryImpl: VerificationRepository {
    private let apiClient: APIClient
    private let sessionSource: VerificationRepository
    private let now: () -> Date
    /// 보내기 시작했지만 접수 여부를 모르는 사진과 처음 보낸 시각. 같은 사진을 다시 보냈을 때 `오늘 이미 제출`이 오면 앞선 전송이 접수된 것이다.
    /// 서버가 거절(4xx)한 사진은 접수되지 않은 것이 확실해 뺀다.
    private var unconfirmedPhotos: [UUID: Date] = [:]

    init(apiClient: APIClient, sessionSource: VerificationRepository, now: @escaping () -> Date = Date.init) {
        self.apiClient = apiClient
        self.sessionSource = sessionSource
        self.now = now
    }

    /// 마감 시각을 몰라 `.open(deadline: nil)`로 두고(남은 시간 숨김), 인증 시간 밖이면 제출 때 서버 403으로 막는다.
    func fetchSession() async throws -> VerificationSession {
        let today = try await todayVerification()
        let base = try await sessionSource.fetchSession()
        let availability: VerificationAvailability = if let today {
            .alreadySubmitted(submittedAt: nil, status: today.reviewStatus.status)
        } else {
            .open(deadline: nil)
        }
        return VerificationSession(area: base.area, window: base.window, availability: availability, serverNow: now())
    }

    /// 서버는 제출 시각을 주지 않아 응답을 받은 시각을 제출 시각으로 쓴다.
    func submit(_ photo: VerificationPhoto) async throws -> VerificationSubmission {
        let firstSentAt = unconfirmedPhotos[photo.id]
        if firstSentAt == nil {
            unconfirmedPhotos[photo.id] = now()
        }
        do {
            let response: SubmitVerificationResponseDTO = try await apiClient.send(
                .submitVerification(photoID: photo.id, jpegData: photo.jpegData)
            )
            unconfirmedPhotos[photo.id] = nil
            return VerificationSubmission(id: String(response.verificationId), submittedAt: now())
        } catch APIError.server(_, "ALREADY_SUBMITTED_TODAY"?) {
            unconfirmedPhotos[photo.id] = nil
            let today = try? await todayVerification()
            // 서버에 재전송 식별자가 없어, 접수 여부를 모르던 같은 사진의 재시도면 앞선 전송이 접수된 것으로 본다.
            if let firstSentAt {
                return VerificationSubmission(id: today.map { String($0.verificationId) }, submittedAt: firstSentAt)
            }
            throw VerificationError.alreadySubmitted(submittedAt: nil, status: today?.reviewStatus.status)
        } catch {
            if Self.isRejectedByServer(error) {
                unconfirmedPhotos[photo.id] = nil
            }
            if case APIError.server(_, "OUT_OF_CERTIFICATION_TIME"?) = error {
                // 인증 시간 밖·주말·방학이 같은 코드로 온다.
                throw VerificationError.deadlinePassed
            }
            throw error
        }
    }

    /// 오늘(KST) 제출한 내 인증. 없으면 nil.
    private func todayVerification() async throws -> MyVerificationResponseDTO? {
        let verifications: [MyVerificationResponseDTO] = try await apiClient.send(.myVerifications)
        let today = ServerDate.startOfDay(now())
        return verifications.first { ServerDate.date($0.date) == today }
    }

    /// 서버가 응답으로 거절해 접수되지 않은 것이 확실한 오류. 네트워크 오류·5xx·응답 해석 실패는 접수됐을 수 있다.
    private static func isRejectedByServer(_ error: Error) -> Bool {
        switch error {
        case APIError.server(let statusCode, _): (400..<500).contains(statusCode)
        case APIError.unauthorized, APIError.sessionExpired: true
        default: false
        }
    }
}
