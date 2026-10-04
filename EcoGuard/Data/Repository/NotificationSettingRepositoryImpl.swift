import Foundation

/// 알림 설정을 `UserDefaults`에 저장한다. 민감 정보가 아니라 Keychain을 쓰지 않는다.
final class NotificationSettingRepositoryImpl: NotificationSettingRepository {
    private enum Key {
        static let cleaningReminder = "notification.cleaningReminder"
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
}
