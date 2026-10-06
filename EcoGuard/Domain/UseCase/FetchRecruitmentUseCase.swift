/// 모집 공고 화면에 필요한 공고와 신청자 정보를 함께 불러온다.
struct FetchRecruitmentUseCase {
    struct Result: Equatable {
        let detail: RecruitmentDetail?
        let applicant: Applicant
    }

    private let recruitmentRepository: RecruitmentRepository

    init(recruitmentRepository: RecruitmentRepository) {
        self.recruitmentRepository = recruitmentRepository
    }

    func execute() async throws -> Result {
        async let detail = recruitmentRepository.fetchRecruitment()
        async let applicant = fetchApplicant()
        return try await Result(detail: detail, applicant: applicant)
    }

    /// 학번·이름은 보조 정보라 받지 못해도 공고는 보여 준다. 화면은 비어 있는 줄을 숨긴다.
    private func fetchApplicant() async -> Applicant {
        (try? await recruitmentRepository.fetchApplicant()) ?? Applicant(studentNumber: nil, name: nil)
    }
}
