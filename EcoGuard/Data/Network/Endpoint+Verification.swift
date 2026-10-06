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
    /// 사진이 없으면 JSON, 있으면 `content` 글자 파트와 `photos` 파일 파트(최대 3장, 넘으면 400 `TOO_MANY_APPEAL_PHOTOS`)로 보낸다.
    /// 서버 요청 한도는 합계 10MB이고 넘으면 500이라, 사진은 `VerificationPhotoEncoder`로 줄인 JPEG만 보낸다.
    static func createAppeal(verificationID: String, content: String, jpegPhotos: [Data] = []) throws -> Endpoint {
        let path = "/api/v1/verifications/\(verificationID)/appeals"
        guard !jpegPhotos.isEmpty else {
            return try Endpoint(method: .post, path: path, json: CreateAppealRequestDTO(content: content))
        }
        var multipart = MultipartFormData()
        multipart.appendField(name: "content", value: content)
        // 서버는 파일 이름이 아니라 실제 이미지 형식으로 확장자를 정한다. 이름은 순서만 드러낸다.
        for (index, jpegData) in jpegPhotos.enumerated() {
            multipart.appendFile(name: "photos", fileName: "photo-\(index + 1).jpg", mimeType: "image/jpeg", data: jpegData)
        }
        return Endpoint(method: .post, path: path, multipart: multipart)
    }

    /// 내 이의신청 전체. 최근에 보낸 것부터.
    static let myAppeals = Endpoint(method: .get, path: "/api/v1/appeals/me")
}
