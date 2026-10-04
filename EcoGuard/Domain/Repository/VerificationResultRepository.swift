protocol VerificationResultRepository {
    /// 제출한 인증 한 건의 검수 결과를 불러온다.
    func fetchResult(id: String) async throws -> VerificationResult
}
