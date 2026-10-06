protocol VerificationRepository {
    func fetchSession() async throws -> VerificationSession
    /// 사진을 제출한다. 같은 사진(`photo.id`)을 다시 보내면 서버가 처음 접수 결과를 돌려준다.
    /// 마감 전에 보내기 시작한 사진(`photo.uploadStartedAt`)은 마감 후 `VerificationSession.lateRetryGrace`까지 재시도를 받는다.
    /// - Throws: `VerificationError`, 네트워크 오류
    func submit(_ photo: VerificationPhoto) async throws -> VerificationSubmission
}
