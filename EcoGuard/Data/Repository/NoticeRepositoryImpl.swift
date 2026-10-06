/// 서버 공지. 목록에는 본문이 없어 본문은 상세로 받는다.
final class NoticeRepositoryImpl: NoticeRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchNotices() async throws -> [Notice] {
        let response: [NoticeListItemResponseDTO] = try await apiClient.send(.notices)
        return try response.map { try $0.toDomain() }
    }

    func fetchNotice(id: Notice.ID) async throws -> Notice? {
        // 서버 ID는 숫자다. 숫자가 아니면 서버에 있을 수 없는 공지다.
        guard let noticeID = Int64(id) else { return nil }
        do {
            let response: NoticeDetailResponseDTO = try await apiClient.send(.notice(id: noticeID))
            return try response.toDomain()
        } catch let error as APIError where error == .server(statusCode: 404, code: "NOTICE_NOT_FOUND") {
            return nil
        }
    }
}
