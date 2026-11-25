extension DIContainer {
    func makeNotificationInboxRepository() -> (any NotificationInboxRepository)? {
        apiClient.map { NotificationRepository(apiClient: $0) }
    }
}
