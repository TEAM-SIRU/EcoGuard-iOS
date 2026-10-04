protocol MyPageRepository {
    func fetchMyPage() async throws -> MyPageSummary
}
