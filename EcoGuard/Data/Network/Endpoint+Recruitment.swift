/// 서버 계약: EcoGuard-Server `recruitment/RecruitmentController.kt`. 학생 API만 쓴다(교사 관리 API는 웹 범위).
nonisolated extension Endpoint {
    /// 내 반의 모집 공고. 진행 중인 모집이 없으면 가장 최근 모집, 그것도 없으면 404 `NO_ACTIVE_RECRUITMENT`.
    static let currentRecruitment = Endpoint(method: .get, path: "/api/v1/recruitments/current")

    /// 신청. 201 `ApplyResponse`.
    static func apply(recruitmentID: Int64, motivation: String) throws -> Endpoint {
        try Endpoint(
            method: .post,
            path: "/api/v1/recruitments/\(recruitmentID)/applications",
            json: ApplyRequestDTO(motivation: motivation)
        )
    }

    /// 가장 최근 신청. 신청한 적이 없으면 404 `NO_APPLICATION`.
    static let myApplication = Endpoint(method: .get, path: "/api/v1/applications/me")
}
