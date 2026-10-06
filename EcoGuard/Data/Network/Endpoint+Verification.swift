import Foundation

/// 서버 계약: EcoGuard-Server `verification/VerificationController.kt`, `aireview/AiReviewController.kt`, `appeal/AppealController.kt`.
/// 교사용(검토 목록·승인/반려 PATCH)은 앱에서 쓰지 않는다.
nonisolated extension Endpoint {
    /// 인증 사진 제출. 성공하면 201 `SubmitVerificationResponseDTO`. 배정 구역 `areaId`는 선택값이라 보내지 않는다.
    static func submitVerification(photoID: UUID, jpegData: Data) -> Endpoint {
        var multipart = MultipartFormData()
        multipart.appendFile(name: "photo", fileName: "\(photoID.uuidString).jpg", mimeType: "image/jpeg", data: jpegData)
        return Endpoint(method: .post, path: "/api/v1/verifications", multipart: multipart)
    }

    /// 내 인증 전체. 최근 날짜부터.
    static let myVerifications = Endpoint(method: .get, path: "/api/v1/verifications/me")

    /// 인증 한 건의 검수 상태. 내 인증이 아니거나 없으면 404 `REVIEW_NOT_FOUND`.
    static func verificationReview(id: String) -> Endpoint {
        Endpoint(method: .get, path: "/api/v1/verifications/\(id)/review")
    }

    /// 반려된 내 인증에 이의신청. 성공하면 201 `CreateAppealResponseDTO`.
    static func createAppeal(verificationID: String, content: String) throws -> Endpoint {
        try Endpoint(method: .post, path: "/api/v1/verifications/\(verificationID)/appeals", json: CreateAppealRequestDTO(content: content))
    }

    /// 내 이의신청 전체. 최근에 보낸 것부터.
    static let myAppeals = Endpoint(method: .get, path: "/api/v1/appeals/me")
}
