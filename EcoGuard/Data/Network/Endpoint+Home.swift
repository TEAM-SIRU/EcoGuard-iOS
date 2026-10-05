import Foundation

/// 홈·마이페이지가 함께 읽는 다른 도메인 API. 해당 도메인 저장소의 엔드포인트와 이름이 겹치지 않게 묶어 둔다.
nonisolated extension Endpoint {
    nonisolated enum Home {
        /// 서버 계약: `cleaningarea/CleaningAreaController.kt`. 배정 전이면 404 `NO_ASSIGNMENT`.
        static let myAssignment = Endpoint(method: .get, path: "/api/v1/assignments/me")
        /// 서버 계약: `verification/VerificationController.kt`. 내 인증 전체, 최신순.
        static let myVerifications = Endpoint(method: .get, path: "/api/v1/verifications/me")
        /// 서버 계약: `recruitment/RecruitmentController.kt`. 신청한 적이 없으면 404 `NO_APPLICATION`.
        static let myApplication = Endpoint(method: .get, path: "/api/v1/applications/me")
        /// 서버 계약: `recruitment/RecruitmentController.kt`. 내 학반 모집이 없으면 404 `NO_ACTIVE_RECRUITMENT`.
        static let currentRecruitment = Endpoint(method: .get, path: "/api/v1/recruitments/current")
        /// 서버 계약: `notice/NoticeController.kt`. 최신순.
        static let notices = Endpoint(method: .get, path: "/api/v1/notices")

        static func notice(id: String) -> Endpoint {
            Endpoint(method: .get, path: "/api/v1/notices/\(id)")
        }
    }
}
