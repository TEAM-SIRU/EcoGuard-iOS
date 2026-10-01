protocol VerificationRepository {
    func fetchSession() async throws -> VerificationSession
    /// 사진을 제출한다. 마감 전에 한 번이라도 보내기 시작한 사진(`photo.id`)은 마감 후에도 재시도를 받는다.
    /// - Throws: `VerificationError`, 네트워크 오류
    func submit(_ photo: VerificationPhoto) async throws -> VerificationSubmission
}
