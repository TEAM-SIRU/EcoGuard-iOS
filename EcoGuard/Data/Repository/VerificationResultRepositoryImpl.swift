import Foundation

/// 인증 결과. 검수 상태는 한 건 조회(`/review`)로, 구역·사진·날짜는 내 인증 목록에서 찾아 합친다.
final class VerificationResultRepositoryImpl: VerificationResultRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchResult(id: String) async throws -> VerificationResult {
        async let review: ReviewResultResponseDTO = apiClient.send(.verificationReview(id: id))
        async let verifications: [MyVerificationResponseDTO] = apiClient.send(.myVerifications)
        let (reviewResponse, myVerifications) = try await (review, verifications)
        // `/review`가 내 인증임을 확인했는데 목록에 없으면 응답이 서로 맞지 않는 것이다.
        guard let verification = myVerifications.first(where: { String($0.verificationId) == id }) else {
            throw APIError.invalidResponse
        }
        return try verification.result(review: reviewResponse, baseURL: apiClient.httpClient.baseURL)
    }
}
