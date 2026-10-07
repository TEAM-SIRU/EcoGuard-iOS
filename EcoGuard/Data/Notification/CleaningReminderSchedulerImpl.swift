import Foundation
import UserNotifications
import os

/// 청소 알림을 기기 로컬 알림으로 건다. 평일(월~금) 요일마다 반복 알림 하나씩, 고정 식별자를 쓴다.
final class CleaningReminderSchedulerImpl: CleaningReminderScheduler {
    /// `DateComponents.weekday` 기준(일 = 1). 월~금.
    static let weekdays = 2...6

    static func identifier(weekday: Int) -> String {
        "cleaningReminder.weekday.\(weekday)"
    }

    static let identifiers = weekdays.map { identifier(weekday: $0) }

    private let center: UserNotificationCenter
    private let logger = Logger(subsystem: "EcoGuard", category: "CleaningReminder")

    init(center: UserNotificationCenter = UNUserNotificationCenter.current()) {
        self.center = center
    }

    func isAuthorized() async -> Bool {
        switch await center.authorizationStatus() {
        case .authorized, .provisional, .ephemeral: true
        case .denied, .notDetermined: false
        @unknown default: false
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            logger.error("알림 권한 요청 실패: \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
            return await isAuthorized()
        }
    }

    func schedule(_ schedule: CleaningReminderSchedule) async {
        let requests = Self.requests(for: schedule)
        // 홈을 갱신할 때마다 불린다. 같은 예약이 이미 걸려 있으면 그대로 둔다.
        let pending = await center.pendingNotificationRequests().filter { Self.identifiers.contains($0.identifier) }
        guard Self.signatures(of: pending) != Self.signatures(of: requests) else { return }
        do {
            for request in requests {
                try await center.add(request)
            }
        } catch {
            logger.error("청소 알림 예약 실패: \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
        }
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: Self.identifiers)
    }

    /// 요일마다 `startMinute`(학교 시간대 KST)에 반복한다.
    static func requests(for schedule: CleaningReminderSchedule) -> [UNNotificationRequest] {
        let content = UNMutableNotificationContent()
        content.title = CleaningReminderCopy.title
        content.body = CleaningReminderCopy.body(areaName: schedule.areaName)
        content.sound = .default
        return weekdays.map { weekday in
            var components = DateComponents()
            components.timeZone = ServerDate.timeZone
            components.weekday = weekday
            components.hour = schedule.startMinute / 60
            components.minute = schedule.startMinute % 60
            return UNNotificationRequest(
                identifier: identifier(weekday: weekday),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
        }
    }

    /// 예약이 같은지 비교할 값(식별자·문구·요일·시각).
    private static func signatures(of requests: [UNNotificationRequest]) -> [String] {
        requests.map { request in
            let components = (request.trigger as? UNCalendarNotificationTrigger)?.dateComponents
            return [
                request.identifier,
                request.content.title,
                request.content.body,
                "\(components?.weekday ?? -1)",
                "\(components?.hour ?? -1)",
                "\(components?.minute ?? -1)"
            ].joined(separator: "|")
        }
        .sorted()
    }
}
