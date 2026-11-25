nonisolated protocol NotificationInboxRepository: Sendable {
    func fetchInbox() async throws -> NotificationInbox
    func markRead(id: Int64) async throws
    func markAllRead() async throws
}
