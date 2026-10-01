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
        async let applicant = recruitmentRepository.fetchApplicant()
        return try await Result(detail: detail, applicant: applicant)
    }
}
