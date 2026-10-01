protocol RecruitmentRepository {
    /// 진행 중이거나 가장 최근 모집 공고. 공고가 없으면 nil.
    func fetchRecruitment() async throws -> RecruitmentDetail?
    /// dataGSM 계정의 학번·이름.
    func fetchApplicant() async throws -> Applicant
    /// 신청한다. 정원·기간·중복은 서버가 판단해 `RecruitmentError`로 알려준다.
    func apply(motivation: String) async throws -> RecruitmentApplication
    /// 내 신청. 신청하지 않았으면 nil.
    func fetchMyApplication() async throws -> RecruitmentApplication?
}
