protocol CleaningAreaRepository {
    /// 학교 도면과 내 청소 구역을 조회한다.
    func fetchCleaningArea() async throws -> CleaningAreaSummary
}
