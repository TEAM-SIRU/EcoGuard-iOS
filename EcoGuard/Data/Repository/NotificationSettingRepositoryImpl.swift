import Foundation

/// 알림 설정을 `UserDefaults`에 저장한다. 민감 정보가 아니라 Keychain을 쓰지 않는다.
final class NotificationSettingRepositoryImpl: NotificationSettingRepository {
    private enum Key {
        static let cleaningReminder = "notification.cleaningReminder"
        static let scheduleAreaName = "notification.cleaningReminder.areaName"
        static let scheduleStartMinute = "notification.cleaningReminder.startMinute"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isCleaningReminderOn() -> Bool {
        // Figma `12 전체`는 켠 상태가 기본이다.
        defaults.object(forKey: Key.cleaningReminder) as? Bool ?? true
    }

    func setCleaningReminderOn(_ isOn: Bool) {
        defaults.set(isOn, forKey: Key.cleaningReminder)
    }

    func cleaningReminderSchedule() -> CleaningReminderSchedule? {
        guard let areaName = defaults.string(forKey: Key.scheduleAreaName),
              let startMinute = defaults.object(forKey: Key.scheduleStartMinute) as? Int else { return nil }
        return CleaningReminderSchedule(areaName: areaName, startMinute: startMinute)
    }

    func setCleaningReminderSchedule(_ schedule: CleaningReminderSchedule?) {
        guard let schedule else {
            defaults.removeObject(forKey: Key.scheduleAreaName)
            defaults.removeObject(forKey: Key.scheduleStartMinute)
            return
        }
        defaults.set(schedule.areaName, forKey: Key.scheduleAreaName)
        defaults.set(schedule.startMinute, forKey: Key.scheduleStartMinute)
    }
}
