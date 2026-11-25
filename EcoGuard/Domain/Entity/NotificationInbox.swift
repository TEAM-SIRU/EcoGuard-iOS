nonisolated struct NotificationInbox: Sendable {
    let unreadCount: Int
    let notifications: [InboxNotification]
}

nonisolated struct InboxNotification: Identifiable, Sendable {
    let id: Int64
    let title: String
    let body: String
    let isRead: Bool
    let createdAt: String
}
