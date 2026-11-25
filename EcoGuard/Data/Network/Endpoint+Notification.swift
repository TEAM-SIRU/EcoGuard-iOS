nonisolated extension Endpoint {
    static let notifications = Endpoint(method: .get, path: "/api/v1/notifications")
    static let readAllNotifications = Endpoint(method: .patch, path: "/api/v1/notifications/read-all")

    static func readNotification(id: Int64) -> Endpoint {
        Endpoint(method: .patch, path: "/api/v1/notifications/\(id)/read")
    }
}
