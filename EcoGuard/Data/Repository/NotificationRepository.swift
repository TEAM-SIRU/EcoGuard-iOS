private nonisolated struct NotificationInboxResponse: Decodable {
    let unreadCount: Int
    let notifications: [NotificationResponse]
}

private nonisolated struct NotificationResponse: Decodable {
    let id: Int64
    let title: String
    let body: String
    let isRead: Bool
    let createdAt: String

    func toDomain() -> InboxNotification {
        InboxNotification(id: id, title: title, body: body, isRead: isRead, createdAt: createdAt)
    }
}

nonisolated struct NotificationRepository: NotificationInboxRepository {
    let apiClient: APIClient

    func fetchInbox() async throws -> NotificationInbox {
        let response: NotificationInboxResponse = try await apiClient.send(.notifications)
        return NotificationInbox(
            unreadCount: response.unreadCount,
            notifications: response.notifications.map { $0.toDomain() }
        )
    }

    func markRead(id: Int64) async throws {
        try await apiClient.send(.readNotification(id: id))
    }

    func markAllRead() async throws {
        try await apiClient.send(.readAllNotifications)
    }
}
