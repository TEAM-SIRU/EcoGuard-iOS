import Foundation

/// 서버 계약: EcoGuard-Server `verification/VerificationController.kt`, `aireview/AiReviewController.kt`, `appeal/AppealController.kt`.
/// 교사용(검토 목록·승인/반려 PATCH)은 앱에서 쓰지 않는다.
nonisolated extension Endpoint {
    /// 인증 사진 제출. 성공하면 201 `SubmitVerificationResponseDTO`. 배정 구역 `areaId`는 선택값이라 보내지 않는다.
    /// `Idempotency-Key`가 같은 재전송은 처음 접수 결과를 그대로 돌려받는다(마감 뒤 포함).
    /// `X-Submit-Started-At`(처음 보내기 시작한 시각)이 인증 시간 안이면 마감 후 유예 시간까지 재시도를 받아 준다.
    static func submitVerification(photoID: UUID, jpegData: Data, startedAt: Date) -> Endpoint {
        var multipart = MultipartFormData()
        multipart.appendFile(name: "photo", fileName: "\(photoID.uuidString).jpg", mimeType: "image/jpeg", data: jpegData)
        return Endpoint(method: .post, path: "/api/v1/verifications", multipart: multipart)
            .with(headers: [
                "Idempotency-Key": photoID.uuidString,
                "X-Submit-Started-At": ServerDate.offsetDateTime(startedAt)
            ])
    }

    /// 인증 화면 진입용 오늘 인증 정보(서버 시각·인증 시간·제출 여부). 배정 구역이 없으면 404 `NO_ASSIGNMENT`.
    static let todayVerification = Endpoint(method: .get, path: "/api/v1/verifications/today")

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
