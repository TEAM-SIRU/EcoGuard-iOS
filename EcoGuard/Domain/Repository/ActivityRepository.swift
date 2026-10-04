protocol ActivityRepository {
    func fetchMonth(year: Int, month: Int) async throws -> ActivityMonth
}
